# サンプルデータ・分析結果クエリガイド

ウサコン株式会社（サンプル）のデータ所在・構造・クエリ方法を集約したリファレンス。
分析結果のエクスポートやデータ調査を素早く行うために使用する。

## 1. ウサコン株式会社（サンプル）の固定ID

| 項目 | 値 |
|------|-----|
| **org_id** | `d0c6b8a5-1a2b-4c5d-8e9f-123456789abc` |
| **company_id** | `29b49dec-64a4-45dd-93c6-14f8cc8fbc28` |
| **企業名** | ウサコン株式会社（サンプル） |
| **業界** | 製造業（うさぎのおもちゃ製造・販売） |
| **従業員数** | 120名 |
| **売上高** | 8億円（2024年度） |

## 2. 分析結果テーブルマッピング

### 概要

| 分析種別 | テーブル | フィルタカラム | 備考 |
|---------|---------|--------------|------|
| **変革認識** | `analysis_runs` | `company_id`, `org_id`, `type` | type で種別を区別。`transformation_recognitions` テーブルは現在空 |
| **成熟度評価** | `maturity_evaluations` | `company_id`, `org_id` | 4軸JSONB + overall_score |
| **CSF案** | `csf_proposals` | `company_id`, `org_id` | SWOT分析 + CSFリスト + 実行計画 |
| **デジタル経営戦略** | `digital_strategy_documents` | `company_id`, `org_id` | 10セクションJSONB |

### analysis_runs の type 値（変革認識）

| type | 説明 |
|------|------|
| `transformation_recognition_p1_1_1` | 現状分析（P1-1-1） |
| `transformation_recognition_p1_1_2` | 外部環境分析（P1-1-2） |
| `transformation_recognition_p1_1_3` | 変革可能性分析（P1-1-3） |
| `transformation_recognition_p1_1_4` | 経営判断（P1-1-4） |
| `transformation_recognition_p1_1_full` | 統合結果（P1-1-Full） |

### maturity_evaluations のJSONBカラム

| カラム | 内容 |
|--------|------|
| `mindset` | マインドセット評価 |
| `governance` | ガバナンス評価 |
| `digital_environment` | デジタル環境評価 |
| `digital_utilization` | デジタル利用評価 |
| `overall_score` | 総合スコア（NUMERIC(3,2)） |

### csf_proposals のJSONBカラム

| カラム | 内容 |
|--------|------|
| `swot_analysis` | SWOT分析 |
| `csf_list` | CSF（重要成功要因）リスト |
| `execution_plan` | 実行計画 |
| `document_version` | ドキュメントバージョン（デフォルト '1.0'） |

### digital_strategy_documents のJSONBカラム（10セクション）

| カラム | 内容 |
|--------|------|
| `executive_summary` | エグゼクティブサマリー |
| `strategic_context` | 戦略的コンテキスト |
| `digital_vision` | デジタルビジョン |
| `customer_value` | 顧客価値 |
| `business_model` | ビジネスモデル |
| `strategic_initiatives` | 戦略的施策 |
| `implementation_roadmap` | 実装ロードマップ |
| `performance_metrics` | パフォーマンス指標 |
| `risk_management` | リスク管理 |
| `governance_framework` | ガバナンスフレームワーク |
| `data_it_policy` | データ・IT方針 |

## 3. REST APIクエリテンプレート

> **前提**: `<SERVICE_ROLE_KEY>` はSupabase Service Role Keyに置換。
> 取得: `npx supabase projects api-keys --project-ref bpcpgettbblglikcoqux`

### 変革認識（analysis_runs）

```bash
# 全変革認識の一覧（ウサコンサンプル）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/analysis_runs?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&type=like.transformation_recognition*&select=id,type,status,created_at&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

# 特定タイプの詳細（result JSONB含む）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/analysis_runs?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&type=eq.transformation_recognition_p1_1_1&select=*" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

### 成熟度評価（maturity_evaluations）

```bash
# 一覧取得
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/maturity_evaluations?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=id,overall_score,status,created_at&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

# 詳細取得（全JSONBカラム含む）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/maturity_evaluations?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=*&limit=1&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

### CSF案（csf_proposals）

```bash
# 一覧取得
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/csf_proposals?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=id,document_version,status,created_at&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

# 詳細取得（SWOT分析・CSFリスト・実行計画含む）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/csf_proposals?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=*&limit=1&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

### デジタル経営戦略（digital_strategy_documents）

```bash
# 一覧取得
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/digital_strategy_documents?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=id,version,status,created_at&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

# 詳細取得（全10セクションJSONB含む）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/digital_strategy_documents?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=*&limit=1&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

### 日付範囲フィルタ（全テーブル共通）

```bash
# 2026年1月以降のデータのみ取得（例: analysis_runs）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/analysis_runs?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&created_at=gte.2026-01-01T00:00:00Z&select=*&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

# 特定期間（2026年1月〜2月）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/analysis_runs?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&created_at=gte.2026-01-01T00:00:00Z&created_at=lt.2026-03-01T00:00:00Z&select=*" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

## 4. サンプルデータのシード処理

### ファイル構成

| ファイル | 役割 |
|---------|------|
| `api/_lib/services/sample-company-template.generated.json` | サンプル企業の全データテンプレート（企業情報 + 全分析結果） |
| `api/_lib/services/sampleCompanySeed.js` | シード実行関数（テンプレートからDB投入） |

### エクスポート

```javascript
const { seedSampleCompanyData, SAMPLE_COMPANY_NAME } = require('./sampleCompanySeed');
// SAMPLE_COMPANY_NAME = "ウサコン株式会社（サンプル）"
```

### 内部関数

| 関数 | 役割 |
|------|------|
| `seedSampleCompanyData(orgId)` | メイン: 全サンプルデータをDBに投入 |
| `buildAnalysisRuns()` | analysis_runs レコード生成（5タイプ） |
| `buildMaturityEvaluation()` | maturity_evaluations レコード生成 |
| `buildCsfProposal()` | csf_proposals レコード生成 |
| `buildDigitalStrategyDocument()` | digital_strategy_documents レコード生成 |
| `cleanupPartialSampleData(orgId, companyId)` | サンプルデータ削除（org_id + company_id でフィルタ） |

### シード時のLLMメタデータ

シードデータには以下のLLMメタデータが付与される（本番AI生成データと区別可能）:

```javascript
{
  llm_source: 'mock',
  llm_provider: 'sample-seed',
  llm_model: 'sample-model-v1'
}
```

## 5. データ出力パターン（JSONB → Markdown）

### 推奨手順

1. REST APIで対象レコードを取得（上記テンプレート使用）
2. JONBフィールドをパース
3. Markdown形式に変換して出力

### 出力先

```
docs/PGL4.0/
```

### JSONB → Markdown変換例

```bash
# 1. データ取得（例: デジタル経営戦略の executive_summary）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/digital_strategy_documents?company_id=eq.29b49dec-64a4-45dd-93c6-14f8cc8fbc28&select=executive_summary,digital_vision,strategic_initiatives&limit=1&order=created_at.desc" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" | jq '.[0]'

# 2. jqで整形（特定セクションの抽出）
curl -s "<上記URL>" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" | jq -r '.[0].executive_summary | to_entries[] | "### \(.key)\n\(.value)\n"'
```

### 全分析結果の一括エクスポート手順

```bash
# ステップ1: 全テーブルからデータ取得
COMPANY_ID="29b49dec-64a4-45dd-93c6-14f8cc8fbc28"
BASE_URL="https://bpcpgettbblglikcoqux.supabase.co/rest/v1"
HEADERS='-H "apikey: <SERVICE_ROLE_KEY>" -H "Authorization: Bearer <SERVICE_ROLE_KEY>"'

# ステップ2: 各テーブルからJSON取得
# analysis_runs（変革認識）
curl -s "${BASE_URL}/analysis_runs?company_id=eq.${COMPANY_ID}&type=like.transformation_recognition*&select=type,result" $HEADERS > /tmp/transformation.json

# maturity_evaluations（成熟度評価）
curl -s "${BASE_URL}/maturity_evaluations?company_id=eq.${COMPANY_ID}&select=*&limit=1&order=created_at.desc" $HEADERS > /tmp/maturity.json

# csf_proposals（CSF案）
curl -s "${BASE_URL}/csf_proposals?company_id=eq.${COMPANY_ID}&select=*&limit=1&order=created_at.desc" $HEADERS > /tmp/csf.json

# digital_strategy_documents（デジタル経営戦略）
curl -s "${BASE_URL}/digital_strategy_documents?company_id=eq.${COMPANY_ID}&select=*&limit=1&order=created_at.desc" $HEADERS > /tmp/strategy.json

# ステップ3: Claude Codeに「/tmp/*.json をMarkdown変換して docs/PGL4.0/ に出力して」と依頼
```

## 6. 注意事項

### TIMESTAMP vs TIMESTAMPTZ
- `digital_strategy_documents` は元々 TIMESTAMP（TZなし）で作成されていた
- マイグレーション 20260227100000 で TIMESTAMPTZ に修正済み
- 詳細: MEMORY.md「Supabase TIMESTAMP vs TIMESTAMPTZ の教訓」参照

### transformation_recognitions テーブル
- 初期設計で作成されたが、**現在は空テーブル**
- 変革認識データは全て `analysis_runs` テーブルの `type` カラムで管理
- クエリ時は `analysis_runs` を使用すること

### データ削除
- `cleanupPartialSampleData()` は `org_id` + `company_id` の両方でフィルタして削除
- 対象テーブル: analysis_runs, maturity_evaluations, csf_proposals, digital_strategy_documents, companies

## 7. サンプルデータテンプレートの更新方法

### 更新スクリプト

`api/scripts/updateSampleSeedFromCompany.js` を使用して、DB上の実データからテンプレートを自動再生成できる。

### 実行コマンド

```bash
cd C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app

# サンプル企業自身のDB上データからテンプレートを再生成
node api/scripts/updateSampleSeedFromCompany.js --company-id 29b49dec-64a4-45dd-93c6-14f8cc8fbc28

# ドライラン（ファイル更新せず検証のみ）
node api/scripts/updateSampleSeedFromCompany.js --company-id 29b49dec-64a4-45dd-93c6-14f8cc8fbc28 --dry-run

# 企業名で検索（非サンプル企業を自動検索）
node api/scripts/updateSampleSeedFromCompany.js --company-name "ウサコン株式会社"
```

### 更新されるファイル

| ファイル | 内容 |
|---------|------|
| `api/_lib/services/sample-company-template.generated.json` | テンプレートJSONスナップショット |
| `api/_lib/services/sampleCompanySeed.js` | シード実行関数内の8定数を文字列置換で更新 |

### 更新される8定数

`SAMPLE_COMPANY`, `CURRENT_STATE_ANALYSIS_RESULT`, `EXTERNAL_ENVIRONMENT_RESULT`, `TRANSFORMATION_POSSIBILITIES_RESULT`, `DECISION_MAKING_RESULT`, `MATURITY_EVALUATION_RESULT`, `CSF_PROPOSAL_RESULT`, `DIGITAL_STRATEGY_RESULT`

### 注意点

- **ソース企業の特定**: `--company-id` で直接指定が最も確実。名前検索はデフォルトで `is_sample=false/null` のみ対象
- **メタデータは不変**: `llm_source: 'mock'`, `llm_provider: 'sample-seed'`, `llm_model: 'sample-model-v1'` はスクリプトの置換対象外
- **FULL_TRANSFORMATION_RESULT**: DB上に存在すればそれを使用、なければ4分析から自動合成
- **executive_summary / strategic_context**: PGL4.0で除外済みだがフィールドとして `{}` で残る（データがあればそのまま使用）
- **前提条件**: ソース企業に4種個別分析（p1_1_1〜p1_1_4）+ 成熟度 + CSF + デジタル戦略が全て完了済みであること

---

*作成: 2026-03-02*
*更新: 2026-03-02 - セクション7（テンプレート更新方法）追加*
