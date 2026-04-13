---
name: usacon-partner-registration
description: |
  代理店（パートナー）ユーザーの新規登録。
  パートナー作成/検索 → Auth ユーザー作成 → 組織・billing・プロモーションコード紐付けまで一括実行。
  Supabase REST API + Auth Admin API を使用（Docker不要）。
  トリガー: "代理店登録", "パートナー登録", "partner registration", "代理店ユーザー作成",
  "partner user create", "プロモーションコード付きユーザー作成"
  使用場面: (1) 新規代理店の初期セットアップ、(2) 既存代理店への追加ユーザー登録、
  (3) 既存ユーザーの代理店化
---

# Usacon パートナー（代理店）ユーザー登録スキル

## 概要
代理店（パートナー）ユーザーの新規登録を一括実行するガイド。
パートナー作成/検索 → Auth ユーザー作成 → 組織・billing・プロモーションコード紐付けまで、
Supabase REST API + Auth Admin API で完結する（Docker不要）。

## 接続情報

| 項目 | 値 |
|------|-----|
| **Project Ref** | `bpcpgettbblglikcoqux` |
| **Base URL** | `https://bpcpgettbblglikcoqux.supabase.co` |

### APIキー取得
```bash
npx supabase projects api-keys --project-ref bpcpgettbblglikcoqux
```

### 変数設定（全Phaseで使用）
```bash
SB_URL="https://bpcpgettbblglikcoqux.supabase.co"
SB_KEY="<SERVICE_ROLE_KEY>"  # 上記コマンドで取得

# --- 入力情報（ユーザーに確認） ---
PARTNER_NAME=""         # 代理店名（例: "株式会社ABC"）
PROMO_CODE=""           # プロモーションコード（例: "ABC2026"）
USER_EMAIL=""           # 登録メールアドレス
USER_DISPLAY_NAME=""    # 表示名
USER_PASSWORD=""        # 初期パスワード
ORG_NAME=""             # 組織名（通常はパートナー名と同じ）

# --- Phase実行中に設定される変数 ---
PARTNER_ID=""           # Phase 1 で取得/作成
USER_ID=""              # Phase 2 で取得
ORG_ID=""               # Phase 3 で取得
```

---

## 登録フロー概要

```
Phase 1: パートナー作成/検索
  ↓
Phase 2: ユーザーアカウント作成（Auth Admin API）
  ↓
Phase 3: 組織・メンバーシップ・billing
  ↓
Phase 4: パートナー紐付け（profiles.partner_id）
  ↓
Phase 5: 登録後検証
```

---

## Phase 1: パートナー作成/検索

### 1-1. プロモーションコードで既存パートナー検索
```bash
curl -s "${SB_URL}/rest/v1/partner?promotion_code=eq.${PROMO_CODE}&select=id,name,promotion_code,active" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```
> 結果が返ればそのパートナーを使用 → `PARTNER_ID` を設定して Phase 2 へ

### 1-2. 名前で既存パートナー検索
```bash
curl -s "${SB_URL}/rest/v1/partner?name=eq.${PARTNER_NAME}&select=id,name,promotion_code,active" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```

### 1-3. 新規パートナー作成
既存パートナーが見つからない場合のみ実行。

```bash
curl -s -X POST "${SB_URL}/rest/v1/partner" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"name\": \"${PARTNER_NAME}\",
    \"promotion_code\": \"${PROMO_CODE}\",
    \"active\": true
  }" | jq .
```

> **RLS**: `partner_insert_service_role` ポリシーにより service_role のみ書き込み可能（SB_KEY使用で問題なし）
> **UNIQUE制約**: `promotion_code` に UNIQUE 制約あり。重複時は 409 エラー → 1-1 で検索を案内

### PARTNER_ID を設定
```bash
PARTNER_ID="<取得または作成されたid>"
```

---

## Phase 2: ユーザーアカウント作成

### 2-1. メール重複チェック（admin_users_view）
```bash
curl -s "${SB_URL}/rest/v1/admin_users_view?email=eq.${USER_EMAIL}&select=id,email,created_at" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```
> **既存ユーザーが見つかった場合** → 特殊ケース「既存ユーザーの代理店化」を参照（Phase 4 のみ実行）

### 2-2. Auth Admin API でユーザー作成
```bash
curl -s -X POST "${SB_URL}/auth/v1/admin/users" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${USER_EMAIL}\",
    \"password\": \"${USER_PASSWORD}\",
    \"email_confirm\": true,
    \"user_metadata\": {
      \"full_name\": \"${USER_DISPLAY_NAME}\"
    }
  }" | jq .
```

> **重要**: `email_confirm: true` でメール確認済み状態で作成 → 即座にログイン可能
> **`full_name` キーを使用すること**: `handle_new_user` トリガーは `raw_user_meta_data->>'full_name'` を参照して `profiles.display_name` に設定する。`display_name` キーを使うとトリガーが取得できず空文字列になる。

### USER_ID を設定
```bash
USER_ID="<レスポンスの id>"
```

### 2-3. profiles 自動作成を確認
`handle_new_user` トリガー（`on_auth_user_created`）により `profiles` が自動作成される。

```bash
curl -s "${SB_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=id,display_name,avatar_url,partner_id" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```

> `display_name` が空の場合、手動で更新:
> ```bash
> curl -s -X PATCH "${SB_URL}/rest/v1/profiles?id=eq.${USER_ID}" \
>   -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
>   -H "Content-Type: application/json" \
>   -d "{\"display_name\": \"${USER_DISPLAY_NAME}\"}"
> ```

### 2-4. public.users を手動INSERT
`handle_new_user` トリガーは `public.users` を作成しない → **手動INSERT必須**。
`public.users.email` は `NOT NULL` 制約あり → `email` の指定も必須。

```bash
curl -s -X POST "${SB_URL}/rest/v1/users" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"id\": \"${USER_ID}\",
    \"email\": \"${USER_EMAIL}\"
  }" | jq .
```

---

## Phase 3: 組織・メンバーシップ・billing

### 3-1. organizations 作成
```bash
curl -s -X POST "${SB_URL}/rest/v1/organizations" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"name\": \"${ORG_NAME}\",
    \"plan\": \"free\"
  }" | jq .
```

### ORG_ID を設定
```bash
ORG_ID="<レスポンスの id>"
```

### 3-2. memberships 作成（role: owner）
```bash
curl -s -X POST "${SB_URL}/rest/v1/memberships" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"user_id\": \"${USER_ID}\",
    \"org_id\": \"${ORG_ID}\",
    \"role\": \"owner\"
  }" | jq .
```

### 3-3. billing 初期化（基本: スキップ）

**基本方針: アプリの自動初期化に任せる。**

ユーザーが初回ログイン時に `getOrCreateBillingCustomer()`（`payment.js`）が自動的に以下を初期化:
- `billing.customers` レコード作成
- 後続の決済フローで `subscriptions` / `credit_balances` も初期化

代理店ユーザーは `email_confirm: true` でログイン可能状態で作成されるため、
初回ログインでbillingが自動初期化される。

> **即座にbillingを確認したい場合のみ**、以下のSQLテンプレートを使用:
>
> ```bash
> # billing.customers 作成
> curl -s -X POST "${SB_URL}/rest/v1/rpc/execute_sql" \
>   -H "apikey: ${SB_KEY}" \
>   -H "Authorization: Bearer ${SB_KEY}" \
>   -H "Content-Type: application/json" \
>   -d "{\"query\": \"INSERT INTO billing.customers (id, org_id, email, contract_start_date) VALUES (gen_random_uuid(), '${ORG_ID}', '${USER_EMAIL}', CURRENT_DATE) RETURNING id\"}"
> ```
>
> ⚠️ `execute_sql` RPC関数が存在しない場合は Supabase Dashboard の SQL Editor から直接実行:
> ```sql
> -- billing.customers
> INSERT INTO billing.customers (id, org_id, email, contract_start_date)
> VALUES (gen_random_uuid(), '<ORG_ID>', '<USER_EMAIL>', CURRENT_DATE)
> RETURNING id;
>
> -- billing.subscriptions（CUSTOMER_ID は上記で取得）
> INSERT INTO billing.subscriptions (id, customer_id, plan_code, monthly_credit_quota, status, next_reset_at)
> VALUES (gen_random_uuid(), '<CUSTOMER_ID>', 'free', 10, 'active', (CURRENT_DATE + INTERVAL '1 month'))
> RETURNING id;
>
> -- billing.credit_balances（SUBSCRIPTION_ID は上記で取得）
> INSERT INTO billing.credit_balances (subscription_id, credits_remaining)
> VALUES ('<SUBSCRIPTION_ID>', 10);
> ```
>
> **プラン別クレジット値:**
> | plan_code | monthly_credit_quota | 初期credits |
> |-----------|---------------------|-------------|
> | free | 10 | 10 |
> | standard | 100 | 100 |
> | professional | 500 | 500 |

---

## Phase 4: パートナー紐付け

### 4-1. profiles.partner_id を更新
```bash
# 現在の partner_id を確認
curl -s "${SB_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=id,partner_id" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```

> **⚠️ 既に `partner_id` が設定されている場合**: 上書きしてよいか確認を取ること

```bash
curl -s -X PATCH "${SB_URL}/rest/v1/profiles?id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"partner_id\": \"${PARTNER_ID}\"}" | jq .
```

---

## Phase 5: 登録後検証

```bash
echo "=== 登録検証 ==="

# 1. auth.users（admin_users_view）
echo "--- auth.users ---"
curl -s "${SB_URL}/rest/v1/admin_users_view?id=eq.${USER_ID}&select=id,email,created_at" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# 2. profiles（partner_id 設定済みか確認）
echo "--- profiles ---"
curl -s "${SB_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=id,display_name,partner_id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# 3. public.users
echo "--- public.users ---"
curl -s "${SB_URL}/rest/v1/users?id=eq.${USER_ID}&select=id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# 4. organizations
echo "--- organizations ---"
curl -s "${SB_URL}/rest/v1/organizations?id=eq.${ORG_ID}&select=id,name,plan" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# 5. memberships（role=owner）
echo "--- memberships ---"
curl -s "${SB_URL}/rest/v1/memberships?user_id=eq.${USER_ID}&org_id=eq.${ORG_ID}&select=id,role" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# 6. partner（active=true）
echo "--- partner ---"
curl -s "${SB_URL}/rest/v1/partner?id=eq.${PARTNER_ID}&select=id,name,promotion_code,active" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

echo "=== 検証完了 ==="
```

### 検証チェックリスト
- [ ] `admin_users_view` にユーザーが存在する
- [ ] `profiles.partner_id` が正しい PARTNER_ID に設定されている
- [ ] `profiles.display_name` が設定されている
- [ ] `public.users` にレコードが存在する
- [ ] `organizations` にレコードが存在する（plan=free）
- [ ] `memberships` に role=owner のレコードが存在する
- [ ] `partner` が active=true である

---

## 特殊ケース

### ケース1: 既存パートナーへのユーザー追加
既にパートナーが存在する場合（同じ代理店に複数ユーザーを追加）。

- Phase 1 はスキップ（既存 `PARTNER_ID` を使用）
- Phase 2〜5 を通常どおり実行

### ケース2: 既存ユーザーの代理店化
既にUsaconアカウントを持つユーザーを代理店に紐付ける場合。

- Phase 2-1 で既存ユーザーが見つかる → `USER_ID` を設定
- Phase 2-2〜2-4 はスキップ（ユーザー・profiles・public.users は既存）
- **事前確認（スキップ前に必ず実施）**:
  ```bash
  # public.users の存在確認
  curl -s "${SB_URL}/rest/v1/users?id=eq.${USER_ID}&select=id,email" \
    -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

  # 組織・メンバーシップの存在確認（owner ロール）
  curl -s "${SB_URL}/rest/v1/memberships?user_id=eq.${USER_ID}&role=eq.owner&select=*,organizations(id,name,plan)" \
    -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .
  ```
  > **public.users が存在しない場合** → Phase 2-4 を実行
  > **組織が存在しない場合** → Phase 3 を実行
  > **両方存在する場合** → Phase 3 はスキップ
- **Phase 4 のみ実行**（profiles.partner_id を更新）
- Phase 5 で検証

### ケース3: プロモーションコード重複
`promotion_code` の UNIQUE 制約により 409 エラーが発生。

- Phase 1-1 でプロモーションコード検索を実行
- 既存パートナーが見つかれば、そのパートナーを使用
- 見つからない場合は別のプロモーションコードを設定

### ケース4: billing即時初期化が必要
管理画面で即座にクレジット状況を確認したい場合。

- Phase 3-3 の SQLテンプレートを使用して手動初期化
- 通常はアプリの自動初期化（初回ログイン時）で十分

---

## DB構造メモ

### handle_new_user トリガー（auth.users INSERT時に自動実行）
```sql
-- profiles レコードを自動作成（id, display_name, avatar_url のみ）
-- partner_id は含まれない → Phase 4 で別途設定
INSERT INTO public.profiles (id, display_name, avatar_url)
VALUES (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''),
        coalesce(new.raw_user_meta_data->>'avatar_url', ''))
ON CONFLICT (id) DO NOTHING;
```

### partner テーブル
```sql
CREATE TABLE public.partner (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    promotion_code text NOT NULL UNIQUE,
    active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

### profiles.partner_id
```sql
ALTER TABLE profiles
ADD COLUMN partner_id UUID REFERENCES partner(id) ON DELETE SET NULL;
```

### billing系ビュー（READ-ONLY）
- `billing_customers_view` → SELECT のみ
- `billing_subscriptions_view` → SELECT のみ
- `billing_credit_balances_view` → SELECT + UPDATE（service_role）
- `billing_credit_ledger_view` → SELECT + INSERT（service_role）

> billing.customers / billing.subscriptions への直接INSERTはビュー経由では不可。
> REST API からは `billing` スキーマに直接アクセスできないため、SQL実行が必要。

---

## ロールバック手順

登録途中で失敗した場合、`usacon-account-mgmt` スキルを使って作成済みリソースを削除する。

**削除順序（作成の逆順）:**
1. `profiles.partner_id` を NULL に戻す（Phase 4 のロールバック）
2. `memberships` を削除（Phase 3 のロールバック）
3. `organizations` を削除（Phase 3 のロールバック）
4. `public.users` を削除（Phase 2-4 のロールバック）
5. `auth.users` を削除（Phase 2-2 のロールバック → Auth Admin API DELETE）
6. `partner` を削除（Phase 1-3 のロールバック、必要な場合のみ）

> Step 1〜5 は `usacon-account-mgmt` スキルの Phase 3 を参照。
> Step 6（partner 削除）は `account-mgmt` の範囲外なので以下を実行:
> ```bash
> # profiles.partner_id → ON DELETE SET NULL のため、先にpartner削除可能
> # ただし他ユーザーが同じパートナーを参照している場合は削除しないこと
> curl -s "${SB_URL}/rest/v1/profiles?partner_id=eq.${PARTNER_ID}&select=id" \
>   -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .
> # 参照しているユーザーが0件の場合のみ削除
> curl -s -X DELETE "${SB_URL}/rest/v1/partner?id=eq.${PARTNER_ID}" \
>   -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"
> ```

---

## 登録フローチェックリスト

- [ ] 入力情報を確認した（メール、パスワード、パートナー名、プロモーションコード）
- [ ] Phase 1: パートナーを作成/検索し `PARTNER_ID` を設定した
- [ ] Phase 2-1: メール重複チェックを実施した
- [ ] Phase 2-2: Auth Admin API でユーザーを作成し `USER_ID` を設定した
- [ ] Phase 2-3: profiles の自動作成を確認した（display_name 設定済み）
- [ ] Phase 2-4: public.users を手動INSERTした
- [ ] Phase 3-1: organizations を作成し `ORG_ID` を設定した
- [ ] Phase 3-2: memberships を作成した（role=owner）
- [ ] Phase 3-3: billing初期化方針を決定した（スキップ or SQL手動実行）
- [ ] Phase 4: profiles.partner_id を更新した
- [ ] Phase 5: 全テーブルの整合性を検証した
- [ ] **ユーザーに登録完了を報告した（メール、パスワード、プロモーションコード）**

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| Auth API 422エラー | メールアドレス重複 | 既存ユーザーを検索し、別メールで再試行 |
| プロモーションコード紐付け失敗 | partner IDが存在しない | partner テーブルを確認し、先にパートナーを作成 |
| profiles.display_name が空 | `full_name` でなく `display_name` キーを使用 | Phase 2-2 で `user_metadata` に `full_name` キーを使用すること |
| partner 作成時に 409 エラー | promotion_code の UNIQUE 制約違反 | Phase 1-1 でプロモーションコード検索を実行し、既存パートナーを使用 |
| Phase 2-4 で 409 エラー | public.users に既にレコードが存在 | 既存ユーザーの代理店化フロー（ケース2）を参照 |

---

## 関連スキル
- `usacon` - メイン開発・運用ガイド
- `usacon-account-mgmt` - ユーザーアカウント管理（検索・削除・影響調査） → ロールバック時に使用
- `supabase-cli` - Supabase CLI詳細

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2025-12 (推定) | 初版作成 |
| 2026-03-04 | トラブルシューティングセクション追加、改訂履歴追加 |
