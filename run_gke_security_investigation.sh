#!/bin/bash
# GKE Security Bulletin 完整調查流程
# 1. 創建調查 -> 2. 執行調查 -> 3. 等待完成 -> 4. 顯示結果

PROJECT_ID="tw-rd-tam-jameslu"
LOCATION="global"
BASE_URL="https://geminicloudassist.googleapis.com/v1alpha"

# 設定輸出文件
OUTPUT_FILE="gemini_cloud_assist_response.txt"
> "$OUTPUT_FILE"  # 清空或創建文件

# 記錄函數 - 同時輸出到螢幕和文件
log_output() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

log_separator() {
    log_output "=================================================="
}

# 記錄 JSON 內容（美化格式）
log_json() {
    echo "$1" | python3 -m json.tool | tee -a "$OUTPUT_FILE"
}

# 取得存取權杖
ACCESS_TOKEN=$(gcloud auth print-access-token)

if [ -z "$ACCESS_TOKEN" ]; then
    log_output "❌ 無法取得存取權杖"
    log_output "請先執行: gcloud auth login"
    exit 1
fi

log_output "🚀 GKE Security Bulletin 完整調查流程"
log_separator
log_output "專案: $PROJECT_ID"
log_output "位置: $LOCATION"
log_output "CVE: CVE-2025-38083"
log_output "公告: GCP-2025-039-cos"
log_output "輸出文件: $OUTPUT_FILE"
log_separator

# ============================================
# 步驟 1: 創建 GKE Security 調查
# ============================================
log_output ""
log_output "📝 步驟 1: 創建 GKE Security Bulletin 調查"
log_separator

CREATE_RESPONSE=$(curl -s -X POST \
  "${BASE_URL}/projects/${PROJECT_ID}/locations/${LOCATION}/investigations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "GKE Security Bulletin: CVE-2025-38083 Linux Kernel 權限提升漏洞",
    "labels": {
      "severity": "high",
      "cve-id": "cve-2025-38083",
      "bulletin-id": "gcp-2025-039-cos",
      "affected-project": "fms-p-202411",
      "category": "vulnerability"
    },
    "observations": {
      "security-alert": {
        "title": "GKE Security Posture 發現高危險性漏洞",
        "observationType": "OBSERVATION_TYPE_CLOUD_ALERT",
        "observerType": "OBSERVER_TYPE_USER",
        "text": "Security Command Center 偵測到 GKE 集群存在高危險性安全漏洞。\n\n漏洞編號: CVE-2025-38083\n公告編號: GCP-2025-039-cos\n嚴重程度: HIGH\n影響專案: fms-p-202411\n\n漏洞描述:\nLinux kernel 中發現了一個可導致權限提升的漏洞，此漏洞影響 Container-Optimized OS 節點。攻擊者可能利用此漏洞在節點上獲得更高的權限。\n\n發現時間: 2025-07-21T22:57:01.634Z\nSCC Finding: organizations/559750338438/sources/7103839463865374687/locations/global/findings/427175050736193356",
        "timeIntervals": [
          {
            "startTime": "2025-07-21T22:57:01.634Z"
          }
        ]
      },
      "technical-info": {
        "title": "技術細節與修復版本",
        "observationType": "OBSERVATION_TYPE_TEXT_DESCRIPTION",
        "observerType": "OBSERVER_TYPE_USER",
        "text": "CVE ID: CVE-2025-38083\n發布日期: 2025-07-15T19:41:20Z\n安全公告: GCP-2025-039-cos\n\n受影響組件: Linux kernel (Container-Optimized OS)\n所有低於 1.30.12-gke.1333000 的版本都受到影響\n\n修復版本: 1.30.12-gke.1333000 或更高版本\n\n聯絡人:\n- Security: jamesylin@taiwanmobile.com\n- Technical: jamesylin@taiwanmobile.com",
        "timeIntervals": [
          {
            "startTime": "2025-07-21T22:57:01.634Z"
          }
        ]
      },
      "remediation-request": {
        "title": "如何修復此 GKE 安全漏洞？",
        "observationType": "OBSERVATION_TYPE_TEXT_DESCRIPTION",
        "observerType": "OBSERVER_TYPE_USER",
        "text": "問題:\n如何修復 CVE-2025-38083 漏洞？需要將 GKE NodePool 升級到哪個版本？\n\n需要的資訊:\n1. 詳細的 NodePool 升級步驟\n2. 具體的 gcloud 或 kubectl 升級命令\n3. 升級過程中可能的服務中斷和注意事項\n4. 如何驗證升級後漏洞已修復\n5. 避免未來出現類似安全問題的最佳實踐\n\n目標版本: 1.30.12-gke.1333000 或更高\n\n參考: https://cloud.google.com/kubernetes-engine/docs/how-to/upgrading-a-cluster#upgrading-nodes",
        "timeIntervals": [
          {
            "startTime": "2025-07-21T22:57:01.634Z"
          }
        ]
      }
    }
  }')

log_json "$CREATE_RESPONSE"

# 提取調查和修訂版本資訊
INVESTIGATION_NAME=$(echo "$CREATE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('name', ''))" 2>/dev/null)
REVISION_NAME=$(echo "$CREATE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('revision', ''))" 2>/dev/null)

if [ -z "$INVESTIGATION_NAME" ] || [ -z "$REVISION_NAME" ]; then
    log_output ""
    log_output "❌ 創建調查失敗"
    exit 1
fi

INVESTIGATION_ID=$(echo "$INVESTIGATION_NAME" | awk -F'/' '{print $NF}')
REVISION_ID=$(echo "$REVISION_NAME" | awk -F'/' '{print $NF}')

log_output ""
log_output "✅ 調查創建成功！"
log_output "   Investigation ID: $INVESTIGATION_ID"
log_output "   Revision ID: $REVISION_ID"

# ============================================
# 步驟 2: 執行調查
# ============================================
log_output ""
log_output "▶️  步驟 2: 執行調查 (啟動 AI 分析)"
log_separator

RUN_RESPONSE=$(curl -s -X POST \
  "${BASE_URL}/projects/${PROJECT_ID}/locations/${LOCATION}/investigations/${INVESTIGATION_ID}/revisions/${REVISION_ID}:run" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

log_json "$RUN_RESPONSE"

OPERATION_NAME=$(echo "$RUN_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('name', ''))" 2>/dev/null)

if [ -z "$OPERATION_NAME" ]; then
    log_output ""
    log_output "❌ 執行調查失敗"
    exit 1
fi

OPERATION_ID=$(echo "$OPERATION_NAME" | awk -F'/' '{print $NF}')

log_output ""
log_output "✅ 調查開始執行！"
log_output "   Operation ID: $OPERATION_ID"

# ============================================
# 步驟 3: 等待調查完成
# ============================================
log_output ""
log_output "⏳ 步驟 3: 等待調查完成..."
log_separator

MAX_WAIT=300  # 最多等待 5 分鐘
WAIT_TIME=0
CHECK_INTERVAL=5

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    log_output "⏱️  檢查狀態... (已等待 ${WAIT_TIME}s)"
    
    STATUS_RESPONSE=$(curl -s -X GET \
      "${BASE_URL}/${OPERATION_NAME}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}")
    
    IS_DONE=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(str(data.get('done', False)))" 2>/dev/null)
    
    if [ "$IS_DONE" = "True" ]; then
        log_output ""
        log_output "✅ 調查執行完成！"
        log_output ""
        log_output "📊 Operation 最終狀態:"
        log_separator
        log_json "$STATUS_RESPONSE"
        break
    fi
    
    sleep $CHECK_INTERVAL
    WAIT_TIME=$((WAIT_TIME + CHECK_INTERVAL))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log_output ""
    log_output "⚠️  等待超時 (${MAX_WAIT}s)"
    log_output "調查可能仍在執行中，請稍後使用以下命令檢查："
    log_output ""
    log_output "curl -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" \\"
    log_output "  ${BASE_URL}/${OPERATION_NAME}"
    log_output ""
fi

# ============================================
# 步驟 4: 獲取最終結果
# ============================================
log_output ""
log_output "📋 步驟 4: 獲取調查結果"
log_separator

RESULT_RESPONSE=$(curl -s -X GET \
  "${BASE_URL}/projects/${PROJECT_ID}/locations/${LOCATION}/investigations/${INVESTIGATION_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

log_json "$RESULT_RESPONSE"

# ============================================
# 步驟 5: 結果摘要
# ============================================
log_output ""
log_separator
log_output "📈 調查結果摘要"
log_separator

EXEC_STATE=$(echo "$RESULT_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('executionState', 'UNKNOWN'))" 2>/dev/null)
OBS_COUNT=$(echo "$RESULT_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('observations', {})))" 2>/dev/null)

log_output "Investigation ID: $INVESTIGATION_ID"
log_output "執行狀態: $EXEC_STATE"
log_output "觀察結果數量: $OBS_COUNT"
log_output ""

# 列出所有觀察結果
log_output "🔍 觀察結果列表:"
echo "$RESULT_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    observations = data.get('observations', {})
    if observations:
        for obs_id, obs in observations.items():
            title = obs.get('title', 'N/A')
            obs_type = obs.get('observationType', 'N/A')
            print(f'  • {obs_id}')
            print(f'    標題: {title}')
            print(f'    類型: {obs_type}')
            print()
    else:
        print('  (無觀察結果)')
except:
    print('  (無法解析觀察結果)')
" | tee -a "$OUTPUT_FILE"

log_output ""
log_output "🔗 在 Console 中查看:"
log_output "https://console.cloud.google.com/gemini/cloud-assist/investigations/${INVESTIGATION_ID}?project=${PROJECT_ID}"
log_output ""
log_separator
log_output "✅ 完整流程執行完畢！"
log_output "📄 完整回應已保存至: $OUTPUT_FILE"
log_separator
