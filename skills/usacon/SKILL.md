---
name: usacon
description: digital-management-consulting-app（Usacon/ウサコン）の開発・運用ガイド。Supabase・Vercel・Stripe連携、PowerShell環境での注意点、トラブルシューティングを含む。テスト時はPlaywright・Supabase・VercelのMCPプラグインを使用。決済テストはStripe CLI（プラグインなし）を使用。
---

# Usacon（ウサコン） - デジタル経営コンサルティングアプリ

## 概要
DX推進支援のためのSaaSアプリケーション。企業のデジタル戦略分析、成熟度評価、変革提案を行う。ITコーディネーターの経営支援業務を、AIアシスタント「ウサコン」がサポートする。

> **動的読み込みルール**: `references/` 配下のファイルは起動時に一括読み込みしない。該当タスクの実行時に必要なファイルのみ Read ツールで読み込むこと。

**トリガー:** `usacon`, `ウサコン`, `デジタル経営`, `digital-management-consulting`, `DXアプリ`, `コンサルアプリ`

## プロジェクト情報

| 項目 | 値 |
|------|-----|
| **ローカルリポジトリ** | `C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app` |
| **本番URL** | https://usacon-ai.com |
| **プレビューURL** | https://preview.usacon-ai.com |
| **旧URL** | https://digital-management-consulting-app.vercel.app |
| **Vercelプロジェクト名** | digital-management-consulting-app |
| **Supabaseプロジェクト名** | Dennolink |
| **Supabase Project Ref** | bpcpgettbblglikcoqux |
| **リージョン** | Northeast Asia (Tokyo) |

## Supabase 接続

### プロジェクトリンク
```bash
npx supabase link --project-ref bpcpgettbblglikcoqux
```

### 主要テーブル（全51エンティティ）
> 全テーブル・ビュー・ENUM・関連図・マイグレーション61件の詳細は references/supabase-tables.md を参照

- **public(38)**: organizations, memberships, companies, company_versions, profiles, users, user_settings, notification_settings, partner, analysis_runs, transformation_recognitions, maturity_evaluations, maturity_roadmaps, transformation_visions, csf_proposals, corporate_strategies, digital_strategies, digital_strategy_documents, conversation_threads/messages/thread_flags/insights, generated_files, executive_question_catalog/logs, executive_weekly_summaries, subsidy_favorites, subsidy_ai_recommendations, reports, report_history, attachments, assistant_action_jobs/job_items, system_status, audit_logs, stripe_event_logs, email_templates, survey_responses
- **billing(5)**: customers, subscriptions, credit_balances, credit_ledger, webhook_events
- **ビュー(6)**: billing_*_view(4), admin_users_view, admin_credits_view
- **RPC(2)**: get_partner_id_by_promo_code, is_owner

### REST API アクセス（Docker不要）
```bash
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/companies?select=*" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

## Vercel 接続
```bash
npx vercel ls digital-management-consulting-app --yes
npx vercel inspect <deployment-url>
```

## アーキテクチャ

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Vercel        │     │    Supabase      │     │     Stripe      │
│  (Frontend +    │────▶│  (PostgreSQL +   │◀────│   (決済処理)    │
│   API Routes)   │     │   Auth + RLS)    │     │   Webhooks      │
│   Next.js       │     │   Dennolink      │     └─────────────────┘
└─────────────────┘     └──────────────────┘
        │                 billing.* テーブル
        ▼
┌─────────────────┐
│   AI Analysis   │
│  (Claude API)   │
└─────────────────┘
```

## PowerShell 環境での注意点

Claude Codeのターミナルは `/usr/bin/bash` で実行される。PowerShell構文は使用不可。
- `C:\Users\zooyo` → `/c/Users/zooyo` （Git Bash形式）
- バックスラッシュ `\` は使用しない
- コマンド連結: `command1 && command2`（成功時のみ）/ `command1 ; command2`（常に両方）

## 核心ルール（最重要）

### 1. デプロイフロー（staging経由必須）
```
ローカル開発 → staging ブランチ → preview.usacon-ai.com → 確認OK → main ブランチ → usacon-ai.com
```
- mainブランチへの直接マージは原則禁止
- 必ずstagingでE2Eテストを実施すること
- 詳細: references/branching-rules.md

### 2. 自動継続パイプライン（途中停止禁止）

> **実装が完了したら、ユーザーの追加指示を待たずに、以下のパイプラインを自動的に最後まで実行すること。**
> **「実装完了しました」で止まることは禁止。必ずstaging→mainマージPR作成まで一気通貫で実行する。**

**トリガー条件:** コード変更が完了し変更目的が達成された / ユーザーから「実装して」等の指示を受けて実装が完了した / Issue起点の実装でステップ5が完了した

**パイプライン:**
```
0  実装整合性検証（import解決・シグネチャ・APIパス・命名規則・ハンドラ網羅性）
1  Lint + 型チェック（npm run lint && cd frontend && npm run type-check）
1.5  Codex final-check（workspace-write、非ブロッキング。失敗時スキップ） → codexスキル参照
1.9  ビルド確認（cd frontend && npx vite build）
2  ブランチ作成 + コミット + プッシュ
3  PR作成（base: staging）
4  クアドレビュー起動（Codex差分 + /sub-review 4エージェント = 計5 Task並列）→ references/quad-review.md
5  gh pr checks --watch（バックグラウンド）
6  レビュー統合 → 修正 → 全チェック通過確認
7  stagingにsquashマージ（ユーザー承認不要）
8  vercel-watchでpreviewデプロイ完了を監視 → references/deploy-wait.md
9  staging E2Eテスト → references/e2e-quality.md
10 Issueクローズ + 関連Issueスキャン（Issue起点の場合のみ。10は中間ステップ、即座に11へ）
11 staging→mainマージPR作成（マージはユーザー承認待ち）
```

**禁止される中間停止パターン（アンチパターン）:**
- 「次のパイプラインに進みますか？」と確認を求める
- 「実装完了サマリー」を提示して報告で止まる
- Lint + 型チェックのみ実施し、ビルド確認を省略する
- E2Eテスト成功後、IssueクローズやmainマージPR作成をせずに止まる
- Issueクローズ完了後、mainマージPR作成に進まず停止する

**例外（自動継続しないケース）:**
- ユーザーが明示的に「コミットしないで」「PRは後で」「マージしないで」と指示した場合
- 変更がドキュメントのみ（.mdファイルのみ）の場合
- 探索・調査タスク（コード変更を伴わない）の場合

> feature→stagingマージはユーザー承認不要。staging→mainマージのPR作成は自動、マージ自体はユーザー承認必須。

### Issueクローズの前提条件
- Issueコメントに `## E2E結果` セクションが存在すること
- Issueコメントに `## クローズ根拠` セクションが存在すること
- 上記2つが確認できてから `state=CLOSED` を設定する
- `implemented` ラベルだけで完了扱いにしない

### 3. E2Eテスト品質基準
- **コード検証（Lint/型チェック/ビルド/コードレビュー）はE2Eの前提条件であり、E2E自体ではない**（Issue #1588教訓）
- 「ページが開いた＝正常」は検証ではない。画面内容を視覚的に確認すること
- 「表示確認のみ」で E2E 完了としてはならない。本番ユーザーの操作フローを再現すること
- 修正対象操作の直接テスト必須（Issue #1071教訓）
- **auto-fill等のAI連携機能は、実際にAPIを叩いて結果を目視確認すること**。コード上の正しさだけではプロンプト↔マッピング間の不整合を検出できない（Issue #1588教訓）
- デプロイ反映検証: E2E開始前にDOM属性でコード変更反映を確認
- 詳細: references/e2e-quality.md

### 4. Codexエスカレーション基準
ブラウザ検査（evaluate/snapshot）3回で原因不明 → `codex-autopilot` スキルでCodexに委任

### 5. ブランチ差異防止
- featureブランチの作成元とPRのbaseは一致させる
- main起点のfeatureをstagingに直接PRしない（逆も同様）
- 詳細: references/branching-rules.md

### 6. CHANGELOG自動更新
- stagingプッシュ時にサブエージェントでchangelog.ts更新
- 詳細: references/changelog-update.md

### 7. PRフロー・CodeRabbit対応
- PR作成直後はCodex差分レビュー+/sub-reviewを先に起動、その後--watch
- CodeRabbitの`pass`だけで判断しない。必ずPRコメントを読むこと
- 詳細: references/pr-flow.md

### 8. 日本語UIデザイン基準（フロントエンドUI変更時 必須）
- **フロントエンドUI変更を含む全Issue**で `awesome-design-md-jp` スキルを参照し、ウサコン標準デザインに準拠すること
- 参照5社: SmartHR（情報階層）、freee（数値・テーブル）、Sansan（Button/Card）、サイボウズ（スペーシング）、LINE（日本語タイポグラフィ）
- `textTransform: 'uppercase'` / 英語向け `letterSpacing: '0.05em'` は日本語UIで使用禁止
- テーマトークン使用必須（ハードコードカラー禁止）、NordLight/Cyberpunk両テーマで表示確認
- 詳細: references/design-standard-jp.md（Issue #1764教訓）

## トラブルシューティング
> 詳細は references/troubleshooting.md を参照

**主要トピック:** mainブランチ誤コミット防止 / Supabase CLI Dockerエラー → REST API / Vercel CLI `--yes` / Stripe Webhook環境変数（`printf`使用）/ Playwright MCPブラウザ競合 → `taskkill`

| 問題 | 症状 | 解決方法 |
|------|------|---------|
| Supabase MCP | OAuth認証エラー | `codex mcp logout && codex mcp login` で再認証を試す。設定変更は再認証失敗時のみ |

## テスト時に使用するツール
> **MCPプラグイン**: Playwright, Supabase, Vercel / **CLI**: Stripe CLI
> 詳細: references/test-tools.md

## 主要ページURL

| ページ | URL |
|--------|-----|
| ダッシュボード | `/dashboard` |
| 企業情報 | `/companies` |
| 分析・評価 | `/processes` |
| レポート | `/reports` |
| 利用規約 | `/legal` |

## 実装チェックリスト
> 詳細は references/checklist-code.md, references/checklist-e2e.md を参照

- **DB変更時**: マイグレーション / `db push` / RLS / 型再生成 / billing影響確認
- **フロントエンド**: ローディング / エラーハンドリング / レスポンシブ / 認証状態
- **決済・Stripe**: テストモード / Webhook / テストカード（4242...）
- **セキュリティ**: 認証チェック / RLS / バリデーション / 機密情報非露出
- **デプロイ前**: `npm run build` / Lint / 環境変数 / プレビュー確認

## 詳細リファレンス

| リファレンス | 内容 |
|-------------|------|
| references/branching-rules.md | ブランチ命名規則、staging運用ルール、差異防止ルール |
| references/changelog-update.md | CHANGELOG更新手順、バージョン決定ルール |
| references/pr-flow.md | PR作成・マージフロー、CodeRabbit対応、デプロイ要件 |
| references/test-tools.md | Playwright/Supabase/Vercel MCP、Stripe CLI、テストアカウント |
| references/quad-review.md | クアドレビュー詳細手順（Codex差分+/sub-review） |
| references/e2e-quality.md | E2Eテスト品質基準・チェックリスト |
| references/deploy-wait.md | デプロイ待機・vercel-watch設定 |
| references/troubleshooting.md | トラブルシューティング集 |
| references/architecture-pitfalls.md | 障害教訓集（504リカバリ、TIMESTAMP等） |
| references/supabase-tables.md | 全テーブル・ENUM・関連図・マイグレーション |
| references/stripe-pricing.md | Stripe料金設計・環境変数管理 |
| references/app-knowledge.md | アプリUI構造・操作ガイド |
| references/sample-data-guide.md | サンプルデータ・分析結果クエリガイド |
| references/checklist-code.md | コードチェック手順 |
| references/checklist-e2e.md | E2Eテスト手順 |
| references/stripe-portal-proration.md | Portal Configuration & 日割り計算ガイド（#1434/#1435教訓） |
| references/design-standard-jp.md | 日本語UIデザイン基準（awesome-design-md-jp準拠、#1764教訓） |

## 関連スキル
- `design-review-checklist` - 設計計画の品質チェックリスト（Issue #723教訓）
- `issue-flow` - GitHub Issue実装の自動ワークフロー → `/issue-flow <番号>`
- `staging-to-main-merge` - staging→mainマージ安全ガイド
- `playwright` / `supabase-cli` / `vercel-cli` / `stripe-cli` / `github-cli`
- `vercel-watch` - Vercelデプロイ状況リアルタイム監視
- `codex-autopilot` - Codex自動運転モード
- `context7` - ライブラリドキュメント検索
- `jgrants` / `gbizinfo` - 補助金検索・法人情報API
- `usacon-account-mgmt` - ユーザーアカウント管理（検索・削除）
- `usacon-partner-registration` - 代理店ユーザー登録
- `usacon-cli` - CLIパッケージ開発ガイド（コマンド一覧・ビルド・テスト・TUI）
- `awesome-design-md-jp` - 日本語UIデザイン基準（フロントエンドUI変更時 必須参照）

## 改訂履歴（SKILL.md）

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-05 | references/に4ファイル抽出、SKILL.mdを250行エントリーポイントにリファクタリング | スキル構造改善（行数924→250、詳細はreferences/に分離） |
| 2026-03-04 | 「難問調査のCodexエスカレーション基準」セクション追加 | Issue #1071教訓: ブラウザ検査10回以上で原因特定できず時間浪費。3回で原因不明ならCodexに委任 |
| 2026-03-04 | ステップ10に11への即時継続指示を追加、アンチパターンに「Issueクローズ後停止」を追加 | 10完了後の「完了感」による11への自動継続漏れ防止 |
| 2026-03-04 | E2Eテスト品質基準に「修正対象操作の直接テスト必須」を追加 | Issue #1071教訓 |
| 2026-03-04 | E2E品質基準・チェックリストに「デプロイ反映検証」を追加 | autopilot-batch-20260304教訓 |
| 2026-03-03 | E2E品質基準・チェックリストに「分析実行テスト」「Issue記載全機能テスト」追加 | Issue #1056教訓 |
| 2026-03-01 | ステップ6.5を関連Issue全件スキャン・クローズに拡張 | Issue #1020閉じ忘れ教訓 |
| 2026-03-01 | トラブルシューティング・クアドレビュー・E2E品質基準・デプロイ待機を references/ に分離 | /skill-improve 行数超過対応 |
| 2026-02-28 | 自動継続パイプライン・ステップ0追加、feature→staging自動マージ | Critical教訓: パイプライン停止禁止違反 |
| 2026-03-17 | 自動継続パイプラインにステップ1.5「Codex final-check」を追加 | PR作成前の軽微修正自動適用と見落とし防止 |
| 2026-03-17 | トラブルシューティングにSupabase MCP再認証手順追加、Issueクローズ前提条件セクション新設 | 教訓#3(MCP OAuth再認証優先)、Issueクローズ品質担保 |
| 2026-03-26 | E2Eテスト品質基準に「コード検証≠E2E」「AI連携機能の実API目視確認」を追加 | Issue #1588教訓: E2Eテスト省略+金額二重変換バグ |
| 2026-04-10 | 核心ルール#8「日本語UIデザイン基準」追加、references/design-standard-jp.md新設 | Issue #1764教訓: awesome-design-md-jp準拠を全フロントエンドUI変更に必須化 |
