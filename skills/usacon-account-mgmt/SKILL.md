---
name: usacon-account-mgmt
description: |
  Usaconユーザーアカウント管理（検索・影響調査・削除）。
  Supabase REST API + Auth Admin APIを使用（Docker不要）。
  トリガー: "ユーザー削除", "アカウント削除", "account delete", "user delete",
  "ユーザー検索", "user lookup", "アカウント管理"
  使用場面: (1) テストアカウントの削除、(2) 退会ユーザーのデータクリーンアップ、
  (3) ユーザーに紐づくデータの影響調査
---

# Usacon ユーザーアカウント管理スキル

## 概要
Usaconアプリのユーザーアカウントに対する検索・影響調査・削除を安全に実行するためのガイド。
Supabase REST API + Auth Admin API を使用し、Docker不要で操作可能。

## 接続情報

| 項目 | 値 |
|------|-----|
| **Project Ref** | `bpcpgettbblglikcoqux` |
| **Base URL** | `https://bpcpgettbblglikcoqux.supabase.co` |

### APIキー取得
```bash
npx supabase projects api-keys --project-ref bpcpgettbblglikcoqux
```

### 変数設定（各Phaseで使用）

> **⚠️ 重要: Claude Code の Bash ツールは呼び出しごとに別シェルが起動される。**
> 変数は次の呼び出しに引き継がれない。以下のいずれかで対処すること:
> 1. **推奨**: 変数定義と使用を **同一の Bash 呼び出し内** にまとめる
> 2. **代替**: 変数を使わず値を直接インラインで埋め込む
>
> スキル内のコード例は変数を使っているが、実行時は必ず同一ブロック内で定義すること。

```bash
# ⚠️ これらは「1つのBash呼び出し内」で定義＆使用すること
SB_URL="https://bpcpgettbblglikcoqux.supabase.co"
SB_KEY="<SERVICE_ROLE_KEY>"  # 上記コマンドで取得
USER_ID=""                    # Phase 1 で特定
USER_EMAIL=""                 # 検索対象メールアドレス
ORG_ID=""                     # Phase 2-2 で特定（組織削除時に使用）

# 例: Phase 1 の検索もこの同じブロック内で実行する
curl -s "${SB_URL}/rest/v1/admin_users_view?email=eq.${USER_EMAIL}" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}"
```

---

## Phase 1: ユーザー検索

### 方法A: admin_users_view（推奨 — ページネーション回避）
Auth Admin APIの `/admin/users` はページネーションがあり、ユーザーが見つからないことがある。
`admin_users_view` ビューを使えばREST APIで直接検索可能。

```bash
curl -s "${SB_URL}/rest/v1/admin_users_view?email=eq.${USER_EMAIL}" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```

### 方法B: Auth Admin API（全ページ走査）
```bash
# ページ1から順に走査（per_page=50がデフォルト）
PAGE=1
while true; do
  RESULT=$(curl -s "${SB_URL}/auth/v1/admin/users?page=${PAGE}&per_page=50" \
    -H "apikey: ${SB_KEY}" \
    -H "Authorization: Bearer ${SB_KEY}")
  MATCH=$(echo "$RESULT" | jq -r ".users[] | select(.email==\"${USER_EMAIL}\")")
  if [ -n "$MATCH" ]; then
    echo "$MATCH" | jq .
    break
  fi
  COUNT=$(echo "$RESULT" | jq '.users | length')
  if [ "$COUNT" -lt 50 ]; then break; fi
  PAGE=$((PAGE + 1))
done
```

### 検索結果からUSER_IDを設定
```bash
USER_ID="<取得したid>"
```

---

## Phase 2: 影響調査（ドライラン）

Phase 2は**データを変更せず**、削除対象ユーザーに紐づくデータの件数を確認する。

### 2-1. 全関連テーブルのデータ件数確認

> **⚠️ 注意**: `-I`（HEADリクエスト）+ `content-range` ヘッダー方式はWindows環境で動作しない。
> 代わりにレスポンスボディの配列長 `jq 'length'` で件数を取得すること。
> HTTP 206 が返った場合は部分コンテンツ（件数 > 1）なので `Range: 0-999` で全件取得して確認。

```bash
# 件数確認用の関数（レスポンスボディ方式 — ヘッダー方式より確実）
# Range: 0-999 で最大1000件まで正確にカウント可能
# ⚠️ select にはフィルタと同じカラム名を使う（idカラムがないテーブルがあるため）
check_count() {
  local table=$1
  local filter=$2
  local select_col=$(echo "$filter" | cut -d'=' -f1)
  local result=$(curl -s "${SB_URL}/rest/v1/${table}?${filter}&select=${select_col}" \
    -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
    -H "Range-Unit: items" -H "Range: 0-999" \
    --write-out "\n%{http_code}" 2>/dev/null)
  local http_code=$(echo "$result" | tail -1)
  local body=$(echo "$result" | sed '$d')
  local count=$(echo "$body" | jq 'length' 2>/dev/null)
  echo "${table}: ${count:-error} (HTTP ${http_code})"
}

echo "=== RESTRICT制約テーブル ==="
check_count "stripe_event_logs" "user_id=eq.${USER_ID}"
check_count "analysis_runs" "created_by=eq.${USER_ID}"
check_count "companies" "created_by=eq.${USER_ID}"
check_count "transformation_recognitions" "created_by=eq.${USER_ID}"
check_count "conversation_threads" "created_by=eq.${USER_ID}"
check_count "email_templates" "created_by=eq.${USER_ID}"

echo ""
echo "=== FK制約なしテーブル ==="
check_count "user_settings" "user_id=eq.${USER_ID}"
check_count "survey_responses" "user_id=eq.${USER_ID}"
check_count "assistant_action_jobs" "user_id=eq.${USER_ID}"
check_count "executive_question_logs" "user_id=eq.${USER_ID}"
check_count "executive_weekly_summaries" "user_id=eq.${USER_ID}"
# account_sessions: テーブルが削除済み（2026-03時点で404）→ スキップ
check_count "generated_files" "created_by=eq.${USER_ID}"
check_count "subsidy_favorites" "created_by=eq.${USER_ID}"
check_count "subsidy_ai_recommendations" "created_by=eq.${USER_ID}"

echo ""
echo "=== CASCADE (public.users) ==="
check_count "notification_settings" "user_id=eq.${USER_ID}"

echo ""
echo "=== CASCADE (auth.users) ==="
check_count "profiles" "id=eq.${USER_ID}"
check_count "memberships" "user_id=eq.${USER_ID}"
check_count "conversation_thread_flags" "user_id=eq.${USER_ID}"
```

### 2-2. 組織オーナーチェック

> **⚠️ 注意**: `memberships` テーブルのFK列は `org_id`（`organization_id` ではない）

```bash
# ユーザーがオーナーの組織を確認
curl -s "${SB_URL}/rest/v1/memberships?user_id=eq.${USER_ID}&role=eq.owner&select=*,organizations(*)" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .

# オーナーの場合、組織内の他メンバーを確認（ORG_IDは上の結果から取得）
curl -s "${SB_URL}/rest/v1/memberships?org_id=eq.${ORG_ID}&select=id,user_id,role" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .
```

> **⚠️ オーナーの場合**: 削除前に権限移譲 or 組織ごと削除が必要（Phase 3 特殊ケース参照）

### 2-3. 複数組織所属チェック
```bash
# 全所属組織を確認
curl -s "${SB_URL}/rest/v1/memberships?user_id=eq.${USER_ID}&select=*,organizations(id,name)" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}" | jq .
```

> **⚠️ 複数組織所属の場合**: auth.users削除時に全組織のmembershipがCASCADE削除される

### 2-4. Stripe顧客チェック

> **⚠️ 注意**: `profiles` テーブルに `email` カラムは存在しない。
> メールアドレスは Phase 1 の `admin_users_view` 結果から取得するか、`USER_EMAIL` 変数を使うこと。

```bash
# Stripe CLI で顧客検索（USER_EMAIL は Phase 1 で設定済み）
stripe customers search --query "email:'${USER_EMAIL}'"
```

---

## Phase 3: 削除実行

> **⚠️ Phase 2 の結果を確認し、ユーザーに承認を得てから実行すること**

### Step 1: RESTRICT制約 + FK制約なしテーブルの手動処理

```bash
# --- Step 1-a: stripe_event_logs（RESTRICT → SET NULL必須）---
curl -s -X PATCH "${SB_URL}/rest/v1/stripe_event_logs?user_id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"user_id": null}'

# --- Step 1-b: analysis_runs（RESTRICT → SET NULL必須）---
curl -s -X PATCH "${SB_URL}/rest/v1/analysis_runs?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"created_by": null}'

# --- Step 1-c: companies（RESTRICT → SET NULL必須）---
curl -s -X PATCH "${SB_URL}/rest/v1/companies?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"created_by": null}'

# --- Step 1-d: transformation_recognitions（RESTRICT → SET NULL必須）---
curl -s -X PATCH "${SB_URL}/rest/v1/transformation_recognitions?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"created_by": null}'

# --- Step 1-e: conversation_threads（RESTRICT → SET NULL必須）---
curl -s -X PATCH "${SB_URL}/rest/v1/conversation_threads?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"created_by": null}'

# --- Step 1-f: user_settings（FK制約削除済み → DELETE）---
curl -s -X DELETE "${SB_URL}/rest/v1/user_settings?user_id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"

# --- Step 1-g: survey_responses（FK制約なし → DELETE）---
curl -s -X DELETE "${SB_URL}/rest/v1/survey_responses?user_id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"

# --- Step 1-h: assistant_action_jobs（FK制約なし → SET NULL）---
curl -s -X PATCH "${SB_URL}/rest/v1/assistant_action_jobs?user_id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"user_id": null}'

# --- Step 1-i: executive_question_logs（FK制約なし → SET NULL）---
curl -s -X PATCH "${SB_URL}/rest/v1/executive_question_logs?user_id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"user_id": null}'

# --- Step 1-j: executive_weekly_summaries（FK制約なし → SET NULL）---
curl -s -X PATCH "${SB_URL}/rest/v1/executive_weekly_summaries?user_id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"user_id": null}'

# --- Step 1-k: account_sessions → テーブル削除済み（2026-03時点）スキップ ---

# --- Step 1-l: generated_files（FK制約なし → SET NULL）---
curl -s -X PATCH "${SB_URL}/rest/v1/generated_files?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"created_by": null}'

# --- Step 1-m: subsidy_favorites（FK制約なし, NOT NULL → DELETE）---
# ⚠️ 組織共有データ。org単一ユーザーなら DELETE、他メンバーいれば要検討
curl -s -X DELETE "${SB_URL}/rest/v1/subsidy_favorites?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"

# --- Step 1-n: subsidy_ai_recommendations（FK制約なし, NOT NULL → DELETE）---
# ⚠️ 組織共有データ。org単一ユーザーなら DELETE、他メンバーいれば要検討
curl -s -X DELETE "${SB_URL}/rest/v1/subsidy_ai_recommendations?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"

# --- Step 1-o: email_templates（RESTRICT, NOT NULL → DELETE）---
# ⚠️ created_by は NOT NULL のため SET NULL 不可。テストデータなら DELETE
curl -s -X DELETE "${SB_URL}/rest/v1/email_templates?created_by=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"
```

### Step 2: public.users を DELETE

```bash
curl -s -X DELETE "${SB_URL}/rest/v1/users?id=eq.${USER_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"
```

> 自動処理:
> - `notification_settings` → CASCADE削除
> - `audit_logs.user_id` → SET NULL
> - `maturity_evaluations.created_by` → SET NULL
> - `transformation_visions.created_by` → SET NULL
> - `digital_strategies.created_by` → SET NULL
> - `report_history.generated_by` → SET NULL
> - `company_versions.edited_by` → SET NULL
> - `reports.created_by` → SET NULL
> - `attachments.created_by` → SET NULL
> - `system_status.created_by` → SET NULL

### Step 3: auth.users を DELETE（Auth Admin API）

```bash
curl -s -X DELETE "${SB_URL}/auth/v1/admin/users/${USER_ID}" \
  -H "apikey: ${SB_KEY}" \
  -H "Authorization: Bearer ${SB_KEY}"
```

> 自動処理:
> - `profiles` → CASCADE削除
> - `memberships` → CASCADE削除
> - `conversation_thread_flags` → CASCADE削除

### Step 4: 組織削除（唯一のメンバーだった場合）

Phase 2-2 でオーナーかつ唯一のメンバーだった場合、auth.users 削除後に組織も削除する。

```bash
# ORG_ID は Phase 2-2 で取得済み
curl -s -X DELETE "${SB_URL}/rest/v1/organizations?id=eq.${ORG_ID}" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}"
```

> **⚠️ 注意**: 他メンバーがいる場合はこのステップをスキップすること

---

## Phase 4: 削除後検証

```bash
echo "=== 削除検証 ==="

# auth.users で検索（空であるべき）
echo -n "admin_users_view: "
curl -s "${SB_URL}/rest/v1/admin_users_view?id=eq.${USER_ID}&select=id,email" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# profiles（空であるべき）
echo -n "profiles: "
curl -s "${SB_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# memberships（空であるべき）
echo -n "memberships: "
curl -s "${SB_URL}/rest/v1/memberships?user_id=eq.${USER_ID}&select=id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# public.users（空であるべき）
echo -n "users: "
curl -s "${SB_URL}/rest/v1/users?id=eq.${USER_ID}&select=id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# user_settings（空であるべき）
echo -n "user_settings: "
curl -s "${SB_URL}/rest/v1/user_settings?user_id=eq.${USER_ID}&select=user_id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# notification_settings（空であるべき）
echo -n "notification_settings: "
curl -s "${SB_URL}/rest/v1/notification_settings?user_id=eq.${USER_ID}&select=user_id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# email_templates（空であるべき）
echo -n "email_templates: "
curl -s "${SB_URL}/rest/v1/email_templates?created_by=eq.${USER_ID}&select=created_by" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

# 組織（削除した場合のみ）
echo -n "organizations: "
curl -s "${SB_URL}/rest/v1/organizations?id=eq.${ORG_ID}&select=id" \
  -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" | jq .

echo ""
echo "✅ 全検証完了（すべて [] であること）"
```

---

## DB依存関係マップ

### auth.users 削除時の自動CASCADE
| テーブル | FK列 | マイグレーション |
|---------|------|-----------------|
| `profiles` | id → auth.users(id) | `20251114000000` |
| `memberships` | user_id → auth.users(id) | `20251007000001` |
| `conversation_thread_flags` | user_id → auth.users(id) | `20260130090000` |

### auth.users への参照（ON DELETE未指定 = RESTRICT）→ 事前SET NULL/DELETE必須
| テーブル | FK列 | マイグレーション |
|---------|------|-----------------|
| `stripe_event_logs` | user_id → auth.users(id) | `20260203090000` L30 |
| `analysis_runs` | created_by → auth.users(id) | `20251223063203` L591 |
| `companies` | created_by → auth.users(id) | `20251223063203` L595 |
| `transformation_recognitions` | created_by → auth.users(id) | `20251223063203` L607 |
| `conversation_threads` | created_by → auth.users(id) | ON DELETE未指定 |
| `email_templates` | created_by → auth.users(id) | RESTRICT, NOT NULL → DELETE必須 |

### public.users 削除時の自動CASCADE
| テーブル | FK列 | マイグレーション |
|---------|------|-----------------|
| `notification_settings` | user_id → users(id) | `20251006000000` L452 |

### public.users 削除時の自動SET NULL（データは残る）
| テーブル | FK列 |
|---------|------|
| `audit_logs` | user_id → users(id) |
| `maturity_evaluations` | created_by → users(id) |
| `transformation_visions` | created_by → users(id) |
| `digital_strategies` | created_by → users(id) |
| `report_history` | generated_by → users(id) |
| `company_versions` | edited_by → users(id) |
| `reports` | created_by → users(id) |
| `attachments` | created_by → users(id) |
| `system_status` | created_by → users(id) |

### FK制約なし（手動対応必要）
| テーブル | 対応 | 備考 |
|---------|------|------|
| `user_settings` | DELETE | FK制約は `20251022000002` で削除済み |
| `survey_responses` | DELETE | user_id FK制約なし |
| `assistant_action_jobs` | SET NULL | user_id FK制約なし |
| `executive_question_logs` | SET NULL | user_id FK制約なし |
| `executive_weekly_summaries` | SET NULL | user_id FK制約なし |
| `account_sessions` | ~~DELETE~~ スキップ | テーブル削除済み（2026-03時点で404） |
| `generated_files` | SET NULL | created_by FK制約なし（NULLable） |
| `subsidy_favorites` | DELETE | created_by FK制約なし（NOT NULL → SET NULL不可） |
| `subsidy_ai_recommendations` | DELETE | created_by FK制約なし（NOT NULL → SET NULL不可） |

---

## 特殊ケース対応

### 組織オーナーの場合
Phase 2-2 でオーナーと判明した場合、以下の選択肢を提示:

1. **権限移譲**: 別メンバーをオーナーに昇格してから削除
   ```bash
   # 別メンバーをオーナーに変更
   curl -s -X PATCH "${SB_URL}/rest/v1/memberships?id=eq.<MEMBERSHIP_ID>" \
     -H "apikey: ${SB_KEY}" -H "Authorization: Bearer ${SB_KEY}" \
     -H "Content-Type: application/json" \
     -d '{"role": "owner"}'
   ```
2. **組織ごと削除**: 他メンバーが存在しない場合のみ。他メンバーがいる場合は影響を明示して確認を取る

### 複数組織所属の場合
- Phase 2-3 で複数組織が確認された場合、警告を表示
- auth.users削除時に**全組織の membership が CASCADE で消失**する
- 各組織で当該ユーザーの役割（owner/admin/member）を確認し、影響を列挙

### Stripe顧客がいる場合（組織削除時）
組織ごと削除する場合、Stripeリソースのクリーンアップが必要:
```bash
# サブスクリプションをキャンセル（確認プロンプトが出るので echo "yes" をパイプ）
echo "yes" | stripe subscriptions cancel <SUBSCRIPTION_ID>

# 顧客を削除（同様に確認プロンプト回避）
echo "yes" | stripe customers delete <CUSTOMER_ID>
```

### ロールバック
万が一の誤削除時は Supabase PITR（Point-in-Time Recovery）を利用:
- Supabase Dashboard → Settings → Database → Point-in-Time Recovery
- Proプラン以上で利用可能

---

## 削除フローチェックリスト

- [ ] Phase 1: ユーザーを特定し `USER_ID` を設定した
- [ ] Phase 2-1: 全関連テーブルのデータ件数を確認した
- [ ] Phase 2-2: 組織オーナーチェックを実施した（オーナーなら権限移譲済み）
- [ ] Phase 2-3: 複数組織所属チェックを実施した
- [ ] Phase 2-4: Stripe顧客チェックを実施した（該当あれば対応済み）
- [ ] **ユーザーの承認を得た**
- [ ] Step 1: RESTRICT制約テーブル 6件を SET NULL/DELETE した（email_templates含む）
- [ ] Step 1: FK制約なしテーブル 8件を DELETE/SET NULL した（account_sessionsはスキップ）
- [ ] Step 2: public.users を DELETE した
- [ ] Step 3: auth.users を DELETE した（Auth Admin API）
- [ ] Step 4: 組織を DELETE した（唯一のオーナーだった場合のみ）
- [ ] Phase 4: 削除後検証を実施し、全テーブルでデータなしを確認した

---

## 実践で判明した注意点（2026-03-18 更新）

### 件数確認: ヘッダー方式が動作しない
- `curl -I` + `grep content-range` はWindows環境で空を返す
- **対策**: レスポンスボディの `jq 'length'` で件数を取得する `check_count()` 関数を使用
- HTTP 206（Partial Content）が返った場合は `Range: 0-999` ヘッダーで全件取得して正確な件数を確認

### テーブル名・カラム名の罠
- `profiles` テーブルに `email` カラムは**存在しない** → `admin_users_view` を使用
- `memberships` テーブルのFK列は `org_id`（`organization_id` ではない）

### テーブル消失
- `account_sessions` テーブルは削除済み（2026-03時点で HTTP 404） → スキップ

### 組織オーナーの削除フロー
- オーナーかつ唯一メンバーの場合: auth.users削除後に `organizations` テーブルからも削除
- Phase 4 の検証で `organizations` も空であることを確認

### Claude Code の Bash 変数スコープ問題（最重要）
- Claude Code の `Bash` ツールは **呼び出しごとに別シェルが起動** される
- ある呼び出しで `SB_KEY="..."` を設定しても、次の呼び出しでは空になる
- **対策1（推奨）**: 変数定義と curl コマンドを **同一の Bash 呼び出し内** にまとめる
- **対策2**: 変数を使わず値を直接インラインで埋め込む
- Phase 2-1 の `check_count()` 関数も、変数定義と同じブロックで実行すること

### check_count の select=id 問題（2026-03-05 追加）
- `user_settings` や `notification_settings` には `id` カラムが存在しない
- `select=id` を固定で使うと HTTP 400 エラーになる
- **対策**: フィルタカラムと同じカラム名を select に使う（`cut -d'=' -f1` で自動抽出）
- Phase 4 検証でも `select=id` を避け、テーブルごとに存在するカラムを指定すること

### Stripe CLI の確認プロンプト（2026-03-05 追加）
- `stripe subscriptions cancel` や `stripe customers delete` は確認プロンプトを表示する
- **対策**: `echo "yes" | stripe ...` でパイプして自動応答する

### email_templates テーブルの見落とし（2026-03-18 追加）
- `email_templates.created_by` は `auth.users(id)` へのFK（RESTRICT, NOT NULL）
- Phase 2-1 の影響調査リストに含まれていなかったため、auth.users DELETE時にFK制約エラーが発生
- `created_by` が **NOT NULL** のため SET NULL 不可 → **DELETE で対応**
- **教訓**: 新テーブル追加時は必ずDB依存関係マップとPhase 2-1のcheck_countリストを同時更新すること
- **根本原因**: マイグレーションでテーブルを追加した際にこのスキルの更新が漏れた

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| ユーザー検索で0件 | メールアドレスの大文字小文字不一致 | ilike で大文字小文字を無視して検索 |
| 削除時にFK制約エラー | 依存テーブルにデータが残存 | Phase 2-1 の影響調査で依存データを先に削除/SET NULL |
| `check_count()` が動作しない | Bash変数が別シェルで未定義 | 変数定義と関数を同一 Bash 呼び出し内にまとめる |
| curl -I でcontent-rangeが空 | Windows環境でのヘッダー方式の制限 | レスポンスボディの `jq 'length'` で件数を取得 |
| auth.users DELETE で 403 | APIキーが anon key | service_role key を使用すること |
| auth.users DELETE でFK制約エラー（email_templates） | `email_templates.created_by` が RESTRICT + NOT NULL | SET NULL不可のためDELETEで対応。Phase 2-1で事前確認すること |

---

## 関連スキル
- `usacon` - メイン開発・運用ガイド
- `supabase-cli` - Supabase CLI詳細
- `stripe-cli` - Stripe CLI詳細（Stripe顧客削除時に使用）

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2025-12 (推定) | 初版作成 |
| 2026-03-03 | 実践で判明した注意点セクション追加（件数確認方式、テーブル名の罠、Bash変数スコープ） |
| 2026-03-04 | トラブルシューティングセクション追加、改訂履歴追加 |
| 2026-03-05 | check_count関数のselect=id問題修正（フィルタカラム自動抽出）、Stripe CLI確認プロンプト回避追加 |
| 2026-03-18 | `email_templates` テーブル追加（RESTRICT + NOT NULL → DELETE必須）。Phase 2-1 check_count、Phase 3 Step 1、DB依存関係マップ、チェックリスト、トラブルシューティングを更新 |
