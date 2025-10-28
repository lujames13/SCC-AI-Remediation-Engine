#!/bin/bash
# 檢查現有操作的狀態並獲取結果

PROJECT_ID="tw-rd-tam-jameslu"
LOCATION="global"
BASE_URL="https://geminicloudassist.googleapis.com/v1alpha"

# 你的操作 ID
OPERATION_ID="operation-1761633169957-642322f51e46e-a061e37b-5738f6c7"
INVESTIGATION_ID="4373221f-200f-415f-9953-1f0ff4e80ea4"

# 取得存取權杖
ACCESS_TOKEN=$(gcloud auth print-access-token)

echo "🔍 檢查調查執行狀態"
echo "=================================================="
echo "Operation ID: $OPERATION_ID"
echo ""

# ============================================
# 檢查操作狀態
# ============================================
echo "📊 操作狀態："
echo "=================================================="

STATUS_RESPONSE=$(curl -s -X GET \
  "${BASE_URL}/projects/${PROJECT_ID}/locations/${LOCATION}/operations/${OPERATION_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

echo "$STATUS_RESPONSE" | python3 -m json.tool

IS_DONE=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('done', False))" 2>/dev/null)

if [ "$IS_DONE" = "True" ]; then
    echo ""
    echo "✅ 調查執行完成！"
    
    # ============================================
    # 獲取調查結果
    # ============================================
    echo ""
    echo "📋 調查結果："
    echo "=================================================="
    
    RESULT=$(curl -s -X GET \
      "${BASE_URL}/projects/${PROJECT_ID}/locations/${LOCATION}/investigations/${INVESTIGATION_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}")
    
    echo "$RESULT" | python3 -m json.tool
    
    # 統計觀察結果
    OBS_COUNT=$(echo "$RESULT" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('observations', {})))" 2>/dev/null)
    EXEC_STATE=$(echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('executionState', 'UNKNOWN'))" 2>/dev/null)
    
    echo ""
    echo "=================================================="
    echo "📈 結果摘要"
    echo "=================================================="
    echo "執行狀態: $EXEC_STATE"
    echo "觀察結果數量: $OBS_COUNT"
    
    if [ "$OBS_COUNT" -gt 0 ]; then
        echo ""
        echo "🔍 觀察結果列表："
        echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
observations = data.get('observations', {})
for obs_id, obs in observations.items():
    print(f\"  • {obs_id}: {obs.get('title', 'N/A')}\")"
    fi
else
    echo ""
    echo "⏳ 調查仍在執行中..."
    echo "請稍後再次執行此腳本檢查狀態"
fi

echo ""
echo "🔗 在 Console 中查看："
echo "https://console.cloud.google.com/gemini/cloud-assist/investigations/${INVESTIGATION_ID}?project=${PROJECT_ID}"
