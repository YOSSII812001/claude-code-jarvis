# Supabase データテーブル一覧（リモート環境）

> **Project Ref**: `bpcpgettbblglikcoqux`（Northeast Asia / Tokyo）
> **検証方法**: PostgREST OpenAPI スキーマ + マイグレーションファイル突き合わせ
> **最終更新**: 2026-02-25

---

## public スキーマ — ベーステーブル

### コア（組織・ユーザー）

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `organizations` | 組織（テナント）管理 | id(PK), name, plan, status, created_at | マルチテナントのルート |
| `memberships` | 組織メンバーシップ | id(PK), org_id(FK→organizations), user_id, role(org_role ENUM), created_at | owner/admin/member/viewer |
| `profiles` | ユーザープロファイル | id(PK), display_name, avatar_url, role, partner_id(FK→partner), last_login_at | Supabase Auth連携 |
| `users` | ユーザー基本情報 | id(PK), email, created_at, updated_at | auth.usersのミラー |
| `user_settings` | ユーザー個人設定 | user_id(PK), locale, theme, timezone, meta(JSONB) | meta内にmax_tokens等 |
| `notification_settings` | 通知設定 | user_id(PK,FK→users), email_digest, product_updates, security_alerts, meta(JSONB) | |
| `partner` | パートナー（代理店）管理 | id(PK), name, promotion_code, active, created_at | プロモーションコード管理 |

### 企業情報

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `companies` | 企業情報 | id(PK), org_id(FK→organizations), name, code, industry, attributes(JSONB), size, employees, revenue, is_sample | 26項目入力、分析の親エンティティ |
| `company_versions` | 企業情報の変更履歴 | id(PK), company_id(FK→companies), version, data(JSONB), edited_by(FK→users), edited_at, summary | バージョン管理 |

### 分析・戦略

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `analysis_runs` | 分析実行履歴（P1-1） | id(PK), org_id(FK→organizations), company_id(FK→companies), type, status(analysis_status), input_params, result, score | LLMメタデータ付き |
| `transformation_recognitions` | 変革認識（P1統合） | id(PK), org_id(FK→organizations), company_id(FK→companies), current_state_analysis, external_environment_analysis, transformation_possibilities, decision_making, status | |
| `maturity_evaluations` | 成熟度評価 | id(PK), company_id(FK→companies), org_id(FK→organizations), evaluation_date, mindset, governance, digital_environment, digital_utilization, overall_score | LLMメタデータ付き |
| `maturity_roadmaps` | 成熟度ロードマップ | id(PK), org_id(FK→organizations), company_id(FK→companies), maturity_evaluation_id(FK→maturity_evaluations), gap_analysis, phases, risks, governance, success_factors, expected_outcomes, investment_plan, status | |
| `transformation_visions` | 変革ビジョン（9セクション） | id(PK), company_id(FK→companies), org_id(FK→organizations), executive_summary, current_state_assessment, transformation_strategy, implementation_plan, expected_outcomes, leadership_message, stakeholder_messages, transformation_scenario, transformation_goals, risk_and_opportunity_assessment, vision | |
| `csf_proposals` | CSF（重要成功要因）提案 | id(PK), company_id(FK→companies), org_id(FK→organizations), swot_analysis(JSONB), csf_list(JSONB), execution_plan(JSONB), status(csf_status) | LLMメタデータ付き |
| `corporate_strategies` | 経営戦略 | id(PK), org_id(FK→organizations), company_id(FK→companies), vision, mission, core_values, strategic_themes, business_units, corporate_objectives, strategic_alignment, portfolio_strategy, synergy_opportunities, resource_allocation, implementation_plan, risk_management, performance_metrics, status | JSONB多数 |
| `digital_strategies` | デジタル戦略（旧） | id(PK), company_id(FK→companies), strategy_overview, resource_allocation, data_and_it_utilization, implementation_roadmap, evaluation_framework, status | |
| `digital_strategy_documents` | デジタル戦略文書（PGL4.0） | id(PK), company_id(FK→companies), org_id, 10+セクション(JSONB), customer_value, business_model, data_it_policy, status, version | LLMメタデータ付き |

### 会話・AIアシスタント

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `conversation_threads` | 会話スレッド | id(PK), company_id(FK→companies), org_id(FK→organizations), title, status, last_message_at | |
| `conversation_messages` | 会話メッセージ | id(PK), thread_id, company_id, role, content, metadata(JSONB) | role: user/assistant |
| `conversation_thread_flags` | スレッドフラグ（ピン/お気に入り） | id(PK), user_id, thread_id, company_id, is_pinned, is_favorite, last_read_at | |
| `conversation_insights` | 会話インサイト | id(PK), thread_id, company_id, fulfillment_score, axis(JSONB), primary_icon, secondary_icon, short_label, summary, tags | |
| `generated_files` | AI生成ファイル | id(PK), file_id, org_id(FK→organizations), thread_id(FK→conversation_threads), filename, mime_type, created_by | |

### 経営者向け機能

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `executive_question_catalog` | 経営質問テンプレート | id(PK), question_text, theme, question_type, answer_mode, options(JSONB), is_active, priority, metadata | バリエーション付き |
| `executive_question_logs` | 経営質問のやり取り履歴 | id(PK), org_id(FK→organizations), company_id(FK→companies), user_id, question_text, answer_text, asked_on, status | |
| `executive_weekly_summaries` | 週次サマリー | id(PK), org_id(FK→organizations), company_id(FK→companies), week_start_date, week_end_date, answer_count, streak_days, dominant_themes, summary_text, encouragement_text, evaluation(JSONB) | ユニーク制約付き |

### 補助金

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `subsidy_favorites` | 補助金お気に入り | id(PK), org_id(FK→organizations), company_id(FK→companies), created_by, subsidy_id, subsidy_name, subsidy_title, memo, status | Jグランツ連携 |
| `subsidy_ai_recommendations` | AI補助金レコメンド | id(PK), org_id(FK→organizations), company_id(FK→companies), created_by, subsidy_id, ai_recommendation_reason, match_score, match_factors(JSONB), application_tips | |

### レポート・ドキュメント

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `reports` | レポート | id(PK), org_id(FK→organizations), company_id(FK→companies), analysis_id(FK→analysis_runs), title, content_md, pdf_storage_path, public_url, status(report_status), version | |
| `report_history` | レポート履歴 | id(PK), company_id(FK→companies), report_type, report_path, generated_by(FK→users), generated_at, accessed_count | |
| `attachments` | 添付ファイル | id(PK), org_id(FK→organizations), company_id(FK→companies), report_id(FK→reports), kind, storage_path, public_url, meta(JSONB), created_by(FK→users) | |

### AIアクション・バッチジョブ

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `assistant_action_jobs` | AIアクションジョブ | id(PK), org_id(FK→organizations), user_id, action_id, tool_use_id, status, sync_mode, item_count, processed_count, success_count, failure_count, last_activity_at | バッチ処理管理 |
| `assistant_action_job_items` | ジョブ個別アイテム | id(PK), job_id(FK→assistant_action_jobs), org_id(FK→organizations), action_id, item_index, status, idempotency_key, input(JSONB), result(JSONB), error(JSONB) | 冪等性管理 |

### システム・監査

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `system_status` | システム状態 | id(PK), scope, org_id(FK→organizations), company_id(FK→companies), key, status(system_status_state), details(JSONB), created_by(FK→users) | |
| `audit_logs` | 監査ログ | id(PK), user_id(FK→users), action, resource_type, resource_id, details(JSONB), ip_address, org_id(FK→organizations), request_id, action_id, job_id, execution_status, credit_policy, idempotency_key | |
| `stripe_event_logs` | Stripe イベントログ | id(PK), stripe_event_id, event_type, stripe_customer_id, user_id(FK→profiles), action, error_message, occurred_at, raw_payload(JSON) | |
| `email_templates` | メールテンプレート | id(PK), subject, body_text, is_sent, last_sent_at, created_by, created_at | |
| `survey_responses` | アンケート回答 | id(PK), user_id, org_id, subscription_id, survey_type, answers(JSONB), status | 解約理由等 |

---

## billing スキーマ — ベーステーブル

| テーブル名 | 用途 | 主要カラム | 備考 |
|-----------|------|-----------|------|
| `billing.customers` | Stripe顧客情報 | id, org_id(FK), stripe_customer_id, contract_start_date, email | org単位 |
| `billing.subscriptions` | サブスクリプション管理 | id, customer_id(FK), plan_code(ENUM), monthly_credit_quota, stripe_subscription_id, price_interval, status | plan_code: free/standard/professional/enterprise |
| `billing.credit_balances` | クレジット残高 | subscription_id(FK), credits_remaining | |
| `billing.credit_ledger` | クレジット使用台帳 | id, subscription_id(FK), change_amount, reason, metadata, occurred_at | 監査証跡 |
| `billing.webhook_events` | Stripe Webhookイベント履歴 | id, event_type, payload, processed_at | 冪等性管理 |

### クレジットクォータ

| プラン | 月間クレジット |
|--------|--------------|
| Free | 5 |
| Standard | 100 |
| Professional | 500 |
| Enterprise | 無制限（NULL） |

---

## ビュー（Views）

| ビュー名 | 用途 | 元テーブル |
|---------|------|-----------|
| `billing_customers_view` | billing.customersのPostgREST公開ビュー | billing.customers |
| `billing_subscriptions_view` | billing.subscriptionsの公開ビュー（org_id, price_interval付き） | billing.subscriptions |
| `billing_credit_balances_view` | billing.credit_balancesの公開ビュー | billing.credit_balances |
| `billing_credit_ledger_view` | billing.credit_ledgerの公開ビュー | billing.credit_ledger |
| `admin_users_view` | 管理者用ユーザー一覧ビュー | users, profiles, organizations, memberships, partner |
| `admin_credits_view` | 管理者用クレジット状況ビュー | organizations, billing.subscriptions, billing.credit_balances |

---

## ENUM型一覧

| ENUM名 | 値 | 使用テーブル |
|--------|-----|------------|
| `analysis_status` | queued, running, completed, failed | analysis_runs |
| `report_status` | draft, published, archived | reports |
| `system_status_state` | ok, warning, error | system_status |
| `org_role` | owner, admin, member, viewer | memberships |
| `csf_status` | draft, reviewing, approved, published | csf_proposals |
| `billing.plan_code` | free, standard, professional, enterprise | billing.subscriptions |
| `llm_source` | claude, fallback, mock | LLMメタデータカラム |

---

## RPC関数

| 関数名 | パラメータ | 用途 |
|--------|-----------|------|
| `get_partner_id_by_promo_code` | promo_code (text) | プロモーションコードからpartner IDを取得 |
| `is_owner` | uid (uuid) | ユーザーがorganization ownerかチェック |

---

## LLMメタデータカラム（共通）

以下のテーブルに共通で追加されている：
- `analysis_runs`, `maturity_evaluations`, `csf_proposals`, `digital_strategy_documents`

| カラム | 型 | 用途 |
|-------|-----|------|
| `llm_source` | llm_source ENUM | AIプロバイダー種別 |
| `llm_provider` | text | プロバイダー名 |
| `llm_model` | text | モデル名 |
| `llm_max_tokens` | integer | 最大トークン数 |
| `llm_temperature` | numeric | 温度パラメータ |
| `llm_request_id` | text | リクエストID |
| `llm_input_tokens` | integer | 入力トークン数 |
| `llm_output_tokens` | integer | 出力トークン数 |

---

## テーブル関連図（簡略）

```
organizations (テナント)
  ├── memberships (org_id FK) ← users
  ├── companies (org_id FK)
  │     ├── company_versions (company_id FK)
  │     ├── analysis_runs (company_id FK)
  │     ├── transformation_recognitions (company_id FK)
  │     ├── maturity_evaluations (company_id FK)
  │     │     └── maturity_roadmaps (maturity_evaluation_id FK)
  │     ├── transformation_visions (company_id FK)
  │     ├── csf_proposals (company_id FK)
  │     ├── corporate_strategies (company_id FK)
  │     ├── digital_strategies (company_id FK)
  │     ├── digital_strategy_documents (company_id FK)
  │     ├── conversation_threads (company_id FK)
  │     │     ├── conversation_messages (thread_id)
  │     │     ├── conversation_thread_flags (thread_id)
  │     │     ├── conversation_insights (thread_id)
  │     │     └── generated_files (thread_id FK)
  │     ├── executive_question_logs (company_id FK)
  │     ├── executive_weekly_summaries (company_id FK)
  │     ├── reports (company_id FK)
  │     │     └── attachments (report_id FK)
  │     ├── report_history (company_id FK)
  │     ├── subsidy_favorites (company_id FK)
  │     ├── subsidy_ai_recommendations (company_id FK)
  │     └── system_status (company_id FK)
  ├── assistant_action_jobs (org_id FK)
  │     └── assistant_action_job_items (job_id FK)
  ├── audit_logs (org_id FK)
  └── billing.customers (org_id FK)
        └── billing.subscriptions (customer_id FK)
              ├── billing.credit_balances (subscription_id FK)
              └── billing.credit_ledger (subscription_id FK)

users (Supabase Auth)
  ├── profiles (user_id FK)
  │     └── partner (partner_id FK)
  ├── user_settings (user_id PK)
  └── notification_settings (user_id PK)

executive_question_catalog (独立マスタ)
survey_responses (独立)
email_templates (独立)
stripe_event_logs (独立・監査用)
billing.webhook_events (独立・監査用)
```

---

## RLS（Row Level Security）

- **リモート環境**: 全テーブルでRLS有効
- **ローカル環境**: 開発用にRLS無効化
- billingスキーマ: 厳格な権限制御（`restrict_billing_view_permissions_strict`）

---

## マイグレーションファイル一覧（61件）

ディレクトリ: `supabase/migrations/`

| ファイル名 | 概要 |
|-----------|------|
| `20251005000000_create_base_schema.sql` | ベーススキーマ作成 |
| `20251006000000_unify_schemas.sql` | スキーマ統一・ENUM定義 |
| `20251006100000_create_analysis_runs.sql` | analysis_runs作成 |
| `20251007000001_add_memberships_and_org_id.sql` | memberships追加 |
| `20251007000002_add_analysis_runs_columns.sql` | analysis_runsカラム追加 |
| `20251009000000_create_csf_proposals.sql` | CSF提案テーブル |
| `20251009000001_add_leadership_and_stakeholder_messages.sql` | リーダーシップメッセージ追加 |
| `20251009000002_add_transformation_scenario.sql` | 変革シナリオ |
| `20251009000003_add_missing_transformation_vision_columns.sql` | ビジョンカラム追加 |
| `20251010000001_create_digital_strategy_documents.sql` | デジタル戦略文書（10セクション） |
| `20251014000000_enable_rls_for_production.sql` | 本番RLS有効化 |
| `20251014000001_update_published_to_completed.sql` | ステータス更新 |
| `20251014000002_fix_digital_strategy_check_constraint.sql` | 制約修正 |
| `20251020000001_add_digital_strategy_10_sections.sql` | 10セクション構造 |
| `20251021000001_create_billing_credit_system.sql` | 課金・クレジットシステム |
| `20251021000002_create_billing_public_views.sql` | 課金パブリックビュー |
| `20251021000003_replace_rules_with_triggers.sql` | トリガーベース更新 |
| `20251022000001_add_max_tokens_default.sql` | トークン設定 |
| `20251022000002_remove_user_settings_fk.sql` | FK制約調整 |
| `20251114000000_account_menu.sql` | アカウントメニュー |
| `20251121000000_fix_theme_constraint.sql` | テーマ制約修正 |
| `20251121010000_force_theme_constraint_fix.sql` | テーマ制約強制修正 |
| `20251203000001_pgl40_digital_strategy_sections.sql` | PGL4.0対応セクション追加 |
| `20251215000001_create_webhook_events.sql` | Webhookイベント追跡 |
| `20251216083930_drop_initialize_default_subscription_rpc.sql` | RPC整理 |
| `20251217010033_update_credit_quota_standard_to_100.sql` | Standard → 100クレジット |
| `20251217010047_add_billing_unique_constraints.sql` | 課金ユニーク制約 |
| `20251217010051_restrict_billing_view_permissions.sql` | ビュー権限制限 |
| `20251217010221_restrict_billing_view_permissions_strict.sql` | ビュー権限厳格化 |
| `20251217033000_enable_rls_billing_tables.sql` | 課金RLS有効化 |
| `20251218030000_add_llm_metadata_columns.sql` | LLMメタデータ追加 |
| `20251223063203_remote_schema.sql` | リモートスキーマダンプ |
| `20251223090000_create_executive_question_tables.sql` | 経営質問テーブル |
| `20251223090100_enable_rls_executive_question_tables.sql` | 経営質問RLS |
| `20251224075627_add_executive_question_catalog_variations.sql` | 質問バリエーション |
| `20251224133000_add_unique_weekly_summaries.sql` | 週次サマリーユニーク制約 |
| `20260106120000_add_evaluation_to_weekly_summaries.sql` | 週次サマリー評価追加 |
| `20260109000000_add_partner_tracking.sql` | パートナー追跡（partner テーブル） |
| `20260109100000_fix_partner_rls_security.sql` | パートナーRLSセキュリティ修正 |
| `20260109110000_add_last_login_sync_trigger.sql` | 最終ログイン同期トリガー |
| `20260123000001_create_subsidy_favorites.sql` | 補助金お気に入り |
| `20260123000002_create_subsidy_ai_recommendations.sql` | AI補助金レコメンド |
| `20260126090000_add_org_id_to_billing_subscriptions_view.sql` | billing_subscriptions_viewにorg_id追加 |
| `20260128000000_fix_default_theme_to_nord_light.sql` | デフォルトテーマをnord-lightに修正 |
| `20260129090000_create_conversation_tables.sql` | 会話テーブル（threads, messages, insights） |
| `20260129091000_enable_rls_conversation_tables.sql` | 会話テーブルRLS |
| `20260130090000_create_conversation_thread_flags.sql` | スレッドフラグ（ピン/お気に入り） |
| `20260130091000_enable_rls_conversation_thread_flags.sql` | スレッドフラグRLS |
| `20260130120000_update_conversation_threads_multi.sql` | 会話スレッド更新 |
| `20260203090000_create_admin_tables.sql` | 管理者テーブル・ビュー |
| `20260203100000_add_price_interval_to_billing_subscriptions.sql` | billing_subscriptionsにprice_interval追加 |
| `20260205013701_add_price_interval_to_admin_credits_view.sql` | admin_credits_viewにprice_interval追加 |
| `20260209070000_fix_numeric_field_overflow.sql` | 数値フィールドオーバーフロー修正 |
| `20260213090000_create_generated_files.sql` | AI生成ファイルテーブル |
| `20260214100000_create_survey_responses.sql` | アンケート回答テーブル |
| `20260215100000_create_assistant_action_jobs.sql` | AIアクションジョブテーブル |
| `20260216100000_add_awaiting_confirmation_status.sql` | awaiting_confirmationステータス追加 |
| `20260217000002_create_strategy_roadmap_tables.sql` | 戦略ロードマップテーブル（corporate_strategies, maturity_roadmaps等） |
| `20260217000003_fix_corporate_strategies_created_by.sql` | corporate_strategies.created_by型修正 |
| `20260217130000_add_is_sample_to_companies.sql` | companies.is_sampleカラム追加 |
| `20260218000001_drop_roadmaps_table.sql` | roadmapsテーブル削除 |

> `archive/` ディレクトリにアーカイブ済みマイグレーションあり

---

## テーブル数サマリー

| 分類 | テーブル数 |
|------|----------|
| public ベーステーブル | 38 |
| billing ベーステーブル | 5 |
| ビュー | 6 |
| RPC関数 | 2 |
| **合計** | **51** |
