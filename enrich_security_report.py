#!/usr/bin/env python3
"""
Gemini API Security Report Enrichment Script
使用 Gemini API 分析 GKE 安全調查報告並提取結構化資訊
"""

import os
import json
import sys
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai

# 載入環境變數
load_dotenv()

# 設定
INPUT_FILE = "gemini_cloud_assist_response.txt"
OUTPUT_FILE = "security_report_enriched.json"
OUTPUT_MD_FILE = "security_report_enriched.md"

def setup_gemini():
    """設定 Gemini API"""
    api_key = os.getenv("API_KEY")
    if not api_key:
        print("❌ 錯誤: 找不到 API_KEY")
        print("請確認 .env 檔案中有設定 API_KEY=your_api_key")
        sys.exit(1)
    
    genai.configure(api_key=api_key)
    return genai.GenerativeModel('gemini-2.0-flash-exp')

def read_input_file():
    """讀取輸入檔案"""
    input_path = Path(INPUT_FILE)
    if not input_path.exists():
        print(f"❌ 錯誤: 找不到檔案 {INPUT_FILE}")
        sys.exit(1)
    
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"✅ 成功讀取檔案: {INPUT_FILE} ({len(content)} 字元)")
    return content

def create_analysis_prompt(content):
    """創建分析提示詞"""
    prompt = f"""
你是一位 GCP 安全專家。請分析以下 GKE Security Bulletin 調查報告，提取並整理關鍵資訊。

報告內容：
{content}

請以 JSON 格式輸出以下結構化資訊：

{{
  "summary": {{
    "title": "漏洞標題",
    "investigation_id": "調查 ID",
    "execution_status": "執行狀態"
  }},
  "vulnerability": {{
    "cve_id": "CVE 編號",
    "bulletin_id": "公告編號",
    "severity": "嚴重程度 (Critical/High/Medium/Low)",
    "severity_score": "CVSS 評分（如果有的話）",
    "published_date": "發布日期",
    "discovery_date": "發現日期"
  }},
  "impact": {{
    "affected_component": "受影響的組件",
    "affected_projects": ["受影響的專案列表"],
    "affected_versions": "受影響的版本範圍",
    "vulnerability_type": "漏洞類型（如：權限提升、遠程代碼執行等）",
    "attack_vector": "攻擊向量",
    "impact_description": "影響描述"
  }},
  "remediation": {{
    "fixed_version": "修復版本",
    "upgrade_required": true/false,
    "upgrade_steps": ["升級步驟列表"],
    "upgrade_commands": ["具體的命令列表"],
    "estimated_downtime": "預估停機時間",
    "rollback_plan": "回滾計劃"
  }},
  "compensating_controls": {{
    "immediate_actions": ["立即可採取的補償措施"],
    "temporary_mitigations": ["臨時緩解措施"],
    "monitoring_recommendations": ["監控建議"],
    "detection_methods": ["檢測方法"]
  }},
  "best_practices": {{
    "prevention": ["預防措施"],
    "automation": ["自動化建議"],
    "policy_recommendations": ["政策建議"]
  }},
  "timeline": {{
    "discovery": "發現時間",
    "notification": "通知時間",
    "patch_available": "補丁可用時間",
    "recommended_completion": "建議完成修復時間"
  }},
  "references": {{
    "official_bulletin": "官方公告連結",
    "documentation": ["相關文檔連結"],
    "console_link": "GCP Console 連結"
  }},
  "risk_assessment": {{
    "exploitability": "可利用性 (High/Medium/Low)",
    "business_impact": "業務影響",
    "urgency": "緊急程度 (Critical/High/Medium/Low)",
    "recommendation": "總體建議"
  }}
}}

注意事項：
1. 如果某些資訊在報告中找不到，請填寫 "未提供" 或 null
2. 確保所有欄位都有值
3. 日期格式請統一為 ISO 8601 格式
4. 列表內容請具體且可操作
5. 只輸出 JSON，不要有其他文字
"""
    return prompt

def analyze_with_gemini(model, content):
    """使用 Gemini API 分析內容"""
    print("🤖 正在使用 Gemini API 分析報告...")
    
    prompt = create_analysis_prompt(content)
    
    try:
        response = model.generate_content(prompt)
        result_text = response.text.strip()
        
        # 移除可能的 markdown 代碼塊標記
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        
        result_text = result_text.strip()
        
        # 解析 JSON
        analysis = json.loads(result_text)
        print("✅ 分析完成！")
        return analysis
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON 解析錯誤: {e}")
        print(f"回應內容: {result_text[:500]}...")
        sys.exit(1)
    except Exception as e:
        print(f"❌ API 呼叫錯誤: {e}")
        sys.exit(1)

def save_json_output(data, filename):
    """儲存 JSON 輸出"""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"✅ JSON 報告已儲存: {filename}")

def generate_markdown_report(data):
    """生成 Markdown 格式報告"""
    md = []
    
    # 標題
    md.append(f"# {data['summary']['title']}")
    md.append("")
    md.append(f"**調查 ID**: `{data['summary']['investigation_id']}`  ")
    md.append(f"**執行狀態**: {data['summary']['execution_status']}  ")
    md.append("")
    
    # 漏洞資訊
    md.append("## 🔴 漏洞資訊")
    md.append("")
    v = data['vulnerability']
    md.append(f"| 項目 | 內容 |")
    md.append(f"|------|------|")
    md.append(f"| **CVE 編號** | `{v['cve_id']}` |")
    md.append(f"| **公告編號** | `{v['bulletin_id']}` |")
    md.append(f"| **嚴重程度** | **{v['severity']}** |")
    if v.get('severity_score'):
        md.append(f"| **CVSS 評分** | {v['severity_score']} |")
    md.append(f"| **發布日期** | {v['published_date']} |")
    md.append(f"| **發現日期** | {v['discovery_date']} |")
    md.append("")
    
    # 影響範圍
    md.append("## 📊 影響範圍")
    md.append("")
    i = data['impact']
    md.append(f"- **受影響組件**: {i['affected_component']}")
    md.append(f"- **漏洞類型**: {i['vulnerability_type']}")
    md.append(f"- **攻擊向量**: {i['attack_vector']}")
    md.append(f"- **受影響版本**: {i['affected_versions']}")
    md.append("")
    md.append("**受影響專案**:")
    for project in i['affected_projects']:
        md.append(f"- {project}")
    md.append("")
    md.append(f"**影響描述**: {i['impact_description']}")
    md.append("")
    
    # 修復措施
    md.append("## 🔧 修復措施")
    md.append("")
    r = data['remediation']
    md.append(f"- **修復版本**: `{r['fixed_version']}`")
    md.append(f"- **需要升級**: {'是' if r['upgrade_required'] else '否'}")
    if r.get('estimated_downtime'):
        md.append(f"- **預估停機時間**: {r['estimated_downtime']}")
    md.append("")
    
    md.append("### 升級步驟")
    md.append("")
    for idx, step in enumerate(r['upgrade_steps'], 1):
        md.append(f"{idx}. {step}")
    md.append("")
    
    if r['upgrade_commands']:
        md.append("### 升級命令")
        md.append("")
        md.append("```bash")
        for cmd in r['upgrade_commands']:
            md.append(cmd)
        md.append("```")
        md.append("")
    
    if r.get('rollback_plan'):
        md.append(f"### 回滾計劃")
        md.append("")
        md.append(f"{r['rollback_plan']}")
        md.append("")
    
    # 補償性措施
    md.append("## 🛡️ 補償性措施")
    md.append("")
    c = data['compensating_controls']
    
    if c['immediate_actions']:
        md.append("### 立即行動")
        md.append("")
        for action in c['immediate_actions']:
            md.append(f"- {action}")
        md.append("")
    
    if c['temporary_mitigations']:
        md.append("### 臨時緩解措施")
        md.append("")
        for mitigation in c['temporary_mitigations']:
            md.append(f"- {mitigation}")
        md.append("")
    
    if c['monitoring_recommendations']:
        md.append("### 監控建議")
        md.append("")
        for rec in c['monitoring_recommendations']:
            md.append(f"- {rec}")
        md.append("")
    
    if c['detection_methods']:
        md.append("### 檢測方法")
        md.append("")
        for method in c['detection_methods']:
            md.append(f"- {method}")
        md.append("")
    
    # 最佳實踐
    md.append("## ⭐ 最佳實踐")
    md.append("")
    bp = data['best_practices']
    
    if bp['prevention']:
        md.append("### 預防措施")
        md.append("")
        for prev in bp['prevention']:
            md.append(f"- {prev}")
        md.append("")
    
    if bp['automation']:
        md.append("### 自動化建議")
        md.append("")
        for auto in bp['automation']:
            md.append(f"- {auto}")
        md.append("")
    
    if bp['policy_recommendations']:
        md.append("### 政策建議")
        md.append("")
        for policy in bp['policy_recommendations']:
            md.append(f"- {policy}")
        md.append("")
    
    # 時間軸
    md.append("## 📅 時間軸")
    md.append("")
    t = data['timeline']
    md.append(f"- **發現時間**: {t['discovery']}")
    md.append(f"- **通知時間**: {t['notification']}")
    md.append(f"- **補丁可用**: {t['patch_available']}")
    md.append(f"- **建議完成時間**: {t['recommended_completion']}")
    md.append("")
    
    # 風險評估
    md.append("## ⚠️ 風險評估")
    md.append("")
    ra = data['risk_assessment']
    md.append(f"| 評估項目 | 結果 |")
    md.append(f"|---------|------|")
    md.append(f"| **可利用性** | {ra['exploitability']} |")
    md.append(f"| **業務影響** | {ra['business_impact']} |")
    md.append(f"| **緊急程度** | **{ra['urgency']}** |")
    md.append("")
    md.append(f"**總體建議**: {ra['recommendation']}")
    md.append("")
    
    # 參考資料
    md.append("## 🔗 參考資料")
    md.append("")
    refs = data['references']
    if refs.get('official_bulletin'):
        md.append(f"- [官方安全公告]({refs['official_bulletin']})")
    if refs.get('console_link'):
        md.append(f"- [GCP Console 調查頁面]({refs['console_link']})")
    if refs.get('documentation'):
        for doc in refs['documentation']:
            md.append(f"- [相關文檔]({doc})")
    md.append("")
    
    # 頁尾
    md.append("---")
    md.append("*此報告由 Gemini API 自動生成*")
    
    return "\n".join(md)

def save_markdown_output(data, filename):
    """儲存 Markdown 輸出"""
    markdown = generate_markdown_report(data)
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(markdown)
    print(f"✅ Markdown 報告已儲存: {filename}")

def main():
    """主函數"""
    print("=" * 60)
    print("🔒 GKE Security Report Enrichment Tool")
    print("=" * 60)
    print()
    
    # 1. 設定 Gemini API
    model = setup_gemini()
    
    # 2. 讀取輸入檔案
    content = read_input_file()
    
    # 3. 使用 Gemini 分析
    analysis_result = analyze_with_gemini(model, content)
    
    # 4. 儲存 JSON 輸出
    save_json_output(analysis_result, OUTPUT_FILE)
    
    # 5. 生成並儲存 Markdown 報告
    save_markdown_output(analysis_result, OUTPUT_MD_FILE)
    
    # 6. 顯示摘要
    print()
    print("=" * 60)
    print("📋 分析摘要")
    print("=" * 60)
    print(f"漏洞: {analysis_result['vulnerability']['cve_id']}")
    print(f"嚴重程度: {analysis_result['vulnerability']['severity']}")
    print(f"修復版本: {analysis_result['remediation']['fixed_version']}")
    print(f"緊急程度: {analysis_result['risk_assessment']['urgency']}")
    print()
    print(f"✅ 完成！請查看:")
    print(f"   - JSON: {OUTPUT_FILE}")
    print(f"   - Markdown: {OUTPUT_MD_FILE}")
    print("=" * 60)

if __name__ == "__main__":
    main()