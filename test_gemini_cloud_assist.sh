#!/bin/bash
# Gemini Cloud Assist API 測試腳本 (使用 curl)
# 已針對專案 tw-rd-tam-jameslu 配置

# ============================================
# 配置
# ============================================
PROJECT_ID="tw-rd-tam-jameslu"
LOCATION="global"

# 取得存取權杖
ACCESS_TOKEN=$(gcloud auth print-access-token)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ 無法取得存取權杖"
    echo "請先執行: gcloud auth login"
    exit 1
fi

echo "🚀 開始測試 Gemini Cloud Assist API"
echo "=========================================="
echo "專案: $PROJECT_ID"
echo "位置: $LOCATION"
echo ""

# ============================================
# 測試 1: 列出支援的位置
# ============================================
echo "📍 測試 1: 列出支援的位置"
echo "=========================================="
curl -s -X GET \
  "https://geminicloudassist.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  | python3 -m json.tool

# ============================================
# 測試 2: 列出現有的調查
# ============================================
echo ""
echo "📋 測試 2: 列出現有的調查"
echo "=========================================="
curl -s -X GET \
  "https://geminicloudassist.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/investigations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  | python3 -m json.tool

# ============================================
# 測試 3: 創建新的調查（最小配置）
# ============================================
echo ""
echo "🔍 測試 3: 創建新的調查（最小配置）"
echo "=========================================="
RESPONSE=$(curl -s -X POST \
  "https://geminicloudassist.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/investigations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "API 測試調查"
  }')

echo "$RESPONSE" | python3 -m json.tool

# 提取 investigation ID
INVESTIGATION_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('name', '').split('/')[-1] if 'name' in data else '')" 2>/dev/null)

# ============================================
# 測試 4: 創建帶完整資訊的調查
# ============================================
echo ""
echo "🔍 測試 4: 創建帶完整資訊的調查"
echo "=========================================="
curl -s -X POST \
  "https://geminicloudassist.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/investigations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "完整測試調查",
    "labels": {
      "environment": "test",
      "purpose": "api-testing"
    },
    "observations": {
      "user-input-1": {
        "title": "測試問題描述",
        "observationType": "OBSERVATION_TYPE_TEXT_DESCRIPTION",
        "observerType": "OBSERVER_TYPE_USER",
        "text": "這是一個 API 測試，用於驗證 Gemini Cloud Assist API 的基本功能。",
        "timeIntervals": [
          {
            "startTime": "2025-10-28T00:00:00Z"
          }
        ]
      }
    }
  }' | python3 -m json.tool

# ============================================
# 測試 5: 如果創建成功，獲取調查詳情
# ============================================
if [ ! -z "$INVESTIGATION_ID" ]; then
    echo ""
    echo "📖 測試 5: 獲取調查詳情"
    echo "=========================================="
    echo "調查 ID: $INVESTIGATION_ID"
    curl -s -X GET \
      "https://geminicloudassist.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/investigations/${INVESTIGATION_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      | python3 -m json.tool
fi

echo ""
echo "=========================================="
echo "✅ 測試完成！"
