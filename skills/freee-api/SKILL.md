---
name: freee Developer API
description: |
  freee Developer APIの5API（会計・人事労務・請求書・工数管理・販売）統合開発ガイド。
  OAuth 2.0認証、レート制限、Webhook、OpenAPI Generator、MCP Serverを含む。
  トリガー: "freee", "freee API", "freee連携", "freee OAuth", "freee Webhook",
  "会計API", "freee会計", "人事労務API", "freee人事", "請求書API",
  "工数管理API", "販売API", "freee MCP", "freee SDK", "freee開発"
---

# freee Developer API ガイド

## 概要

freee株式会社が提供するクラウドバックオフィスサービスのPublic APIプラットフォーム。5つのAPIで会計・人事労務・請求書・工数管理・販売を操作できる。

| 項目 | 値 |
|------|-----|
| APIベースURL | 下記API別ベースURL表を参照（HTTPS必須） |
| 認証方式 | OAuth 2.0 Authorization Code Grant |
| 認可URL | `https://accounts.secure.freee.co.jp/public_api/authorize` |
| トークンURL | `https://accounts.secure.freee.co.jp/public_api/token` |
| 失効URL | `https://accounts.secure.freee.co.jp/public_api/revoke` |
| 開発者ポータル | https://developer.freee.co.jp/ |
| アプリ管理 | https://app.secure.freee.co.jp/developers/applications |
| OpenAPIスキーマ | https://github.com/freee/freee-api-schema（JSON形式、MIT） |
| MCPサーバー | https://github.com/freee/freee-mcp（Claude Desktop/Code対応） |
| Postman | https://www.postman.com/freee-public-api/workspace/freee-public-api-workspace/ |

### API別ベースURL・レート制限

| API | ベースURL | パスプレフィックス | レート制限 |
|-----|----------|-----------------|----------|
| 会計 | `https://api.freee.co.jp` | `/api/1/` | 過度アクセスで403、`/reports`=10 req/sec、`/receipts/{id}/download`=3 req/sec、日次上限 3,000〜10,000（プラン別） |
| 人事労務 | `https://api.freee.co.jp/hr` | `/api/v1/` | 10,000 req/hour、過度アクセスで403+10分クールダウン |
| 請求書 | `https://api.freee.co.jp/iv` | `/invoices`, `/quotations`, `/delivery_slips` | 30 req/min、1,500 req/hour、日次上限 3,000〜10,000 |
| 工数管理 | `https://api.freee.co.jp/pm` | `/projects`, `/workloads`, `/teams` | 5,000 req/hour、過度アクセスで403 |
| 販売 | `https://api.freee.co.jp/sm` | `/businesses`, `/sales_orders`, `/sales` | 30 req/min、1,500 req/hour、過度アクセスで403 |

> **重要**: 各APIのベースURLが異なる。会計は直接 `/api/1/`、その他は `/hr`、`/iv`、`/pm`、`/sm` がプレフィックスとして付く。

---

## 核心ルール

1. **company_idが大半の事業所スコープAPIで必須** — 最初に `GET /api/1/companies` で事業所一覧を取得しcompany_idを保持する。例外: `/companies`, `/users/me`, OAuth系は不要
2. **マスタ同期 → トランザクション操作の順序** — 取引先・勘定科目・税区分・部門・品目のマスタIDを先に同期してから、取引(deals)作成等を行う
3. **アクセストークン有効期限: 6時間（21,600秒）** — 期限切れは `expired_access_token` エラーコードで通知
4. **リフレッシュトークン有効期限: 90日、1回使い切り** — リフレッシュ時に新しいトークンペアが発行される。**古いリフレッシュトークンは即座に無効化**されるため、新しいものを必ず保存すること
5. **公式SDKは定期メンテナンス終了（2023-2024年）** — C#/Java/PHP/JavaScriptの公式SDKはメンテナンス終了・一部アーカイブ済み。OpenAPI Generatorでクライアントコードを自動生成するか、freee MCPサーバーを使用する
6. **レート制限は事業所単位** — 一般: 300 req/min、HR: 10,000 req/hour。超過時は429または403応答
7. **プラン別機能制限あり** — フリープランでは仕訳帳API等が利用不可。`freee_plan_limit` エラーで通知
8. **後方互換ポリシー: 新フィールド・新エンドポイントは予告なし追加** — レスポンスの未知プロパティを無視する設計にすること
9. **stateパラメータ必須（CSRF対策）** — OAuth認可リクエストに必ずランダム文字列を含め、コールバック時に検証する
10. **HTTPS必須** — HTTPアクセスは不可。APIベースURL `https://api.freee.co.jp/` のみ

---

## 認証（OAuth 2.0）

### フロー概要

```
1. ユーザーを認可URLにリダイレクト（prompt=select_company推奨）
2. ユーザーがfreeeにログイン → 事業所選択 → 権限承認
3. コールバックURLに認可コード（code）が返却
4. 認可コードをアクセストークン + リフレッシュトークンに交換
5. アクセストークンでAPI呼び出し
6. 期限切れ時はリフレッシュトークンで更新（新しいペアを必ず保存）
```

### エンドポイント

| 用途 | URL |
|------|-----|
| 認可 | `https://accounts.secure.freee.co.jp/public_api/authorize` |
| トークン取得/更新 | `https://accounts.secure.freee.co.jp/public_api/token` |
| トークン失効 | `https://accounts.secure.freee.co.jp/public_api/revoke` |

### 認可URLパラメータ

| パラメータ | 必須 | 値 |
|-----------|------|-----|
| `response_type` | Yes | `code` |
| `client_id` | Yes | アプリのClient ID |
| `redirect_uri` | Yes | 登録済みコールバックURL |
| `state` | Yes | CSRF対策ランダム文字列 |
| `prompt` | 推奨 | `select_company`（事業所選択画面を表示） |

### スコープ

`read`, `write`, `default_read` — アプリ作成時に設定。変更時は全トークン破棄→再認可が必要。

### トークン有効期限

| トークン | 有効期限 | 備考 |
|---------|---------|------|
| アクセストークン | 6時間（21,600秒） | Authorizationヘッダーで使用 |
| リフレッシュトークン | 90日 | **1回使い切り**、更新時に新トークン保存必須 |

### ローカルテスト

コールバックURLに `urn:ietf:wg:oauth:2.0:oob` を指定すると、認可コードがブラウザに表示される。

### curl例: トークン取得

```bash
curl -X POST "https://accounts.secure.freee.co.jp/public_api/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}"
```

### curl例: トークンリフレッシュ

```bash
curl -X POST "https://accounts.secure.freee.co.jp/public_api/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "refresh_token=${REFRESH_TOKEN}"
```

> **→ 詳細実装パターン（Next.js API Route、TypeScript）**: `references/oauth-flow.md`

---

## 5 API エンドポイント概要

### 会計API（Accounting）

パスプレフィックス: `/api/1/`

| カテゴリ | 主要パス | 操作 |
|---------|---------|------|
| 事業所 | `/companies`, `/companies/{id}` | GET |
| 取引（収入/支出） | `/deals` | GET, POST, PUT, DELETE |
| 取引先 | `/partners` | GET, POST, PUT, DELETE + upsert_by_code |
| 勘定科目 | `/account_items` | GET, POST, PUT, DELETE + code/upsert |
| 部門 | `/sections` | GET, POST, PUT, DELETE + code/upsert |
| 品目 | `/items` | GET, POST, PUT, DELETE |
| メモタグ | `/tags` | GET, POST, PUT, DELETE |
| セグメントタグ | `/segment_tags` | GET, POST, PUT |
| 税区分 | `/taxes` | GET |
| 振替伝票 | `/manual_journals` | GET, POST, PUT |
| 口座振替 | `/transfers` | GET, POST, PUT, DELETE |
| 仕訳帳 | `/journals` | GET（CSV、有料プランのみ） |
| 試算表 | `/trial_balance` | GET |
| 総勘定元帳 | `/general_ledgers` | GET |
| 口座明細 | `/wallet_txns` | GET |
| 口座 | `/walletables` | GET |
| 連携サービス | `/banks` | GET |
| 経費精算 | `/expense_applications` | GET, POST, PUT + actions |
| 支払依頼 | `/payment_requests` | GET, POST, PUT + actions |
| 各種申請 | `/approval_requests` | GET, POST, PUT + actions |
| 申請経路 | `/approval_flow_routes` | GET |
| 経費科目 | `/expense_application_line_templates` | GET |
| ファイルボックス | `/receipts` | GET, POST, DELETE + download |
| 請求書 | `/invoices` | ※freee請求書APIへ移行済 |
| 見積書 | `/quotations` | ※freee請求書APIへ移行済 |
| 固定資産 | `/fixed_assets` | GET, POST, PUT |
| 決算書表示名 | `/account_groups` | GET |
| フォーム選択項目 | `/forms/selectables` | GET |
| ユーザー | `/users/me` | GET |

> **→ 全エンドポイント詳細・パラメータ・連携パターン**: `references/accounting-api.md`

### 人事労務API（HR）

パスプレフィックス: `/hr/api/v1/`、APIバージョン: `2022-02-01`

| カテゴリ | 主要パス | 操作 |
|---------|---------|------|
| ユーザー | `/users/me` | GET |
| 従業員（全体） | `/companies/{cid}/employees` | GET |
| 従業員（月指定） | `/employees` | GET, POST, PUT, DELETE |
| プロフィール | `/employees/{id}/profile_rule` | GET, PUT |
| 健康保険 | `/employees/{id}/health_insurance_rule` | GET, PUT |
| 厚生年金 | `/employees/{id}/welfare_pension_insurance_rule` | GET, PUT |
| 扶養家族 | `/employees/{id}/dependent_rules` | GET, PUT(bulk) |
| 口座情報 | `/employees/{id}/bank_account_rule` | GET, PUT |
| 基本給 | `/employees/{id}/basic_pay_rule` | GET, PUT |
| カスタム項目 | `/employees/{id}/profile_custom_fields` | GET |
| 日次勤怠 | `/employees/{id}/work_records/{date}` | GET, PUT, DELETE |
| 月次勤怠サマリ | `/employees/{id}/work_record_summaries/{y}/{m}` | GET, PUT |
| 打刻 | `/employees/{id}/time_clocks` | GET, POST |

認可レベル: `company_admin`（他従業員データ）、`self_only`（本人のみ）

> **→ 全エンドポイント詳細**: `references/hr-api.md`

### 請求書API（Invoice）

| カテゴリ | 主要パス | 操作 |
|---------|---------|------|
| 請求書 | `/invoices` | GET, POST, PUT |
| 見積書 | `/quotations` | GET, POST, PUT |
| 納品書 | `/delivery_slips` | GET, POST, PUT |
| テンプレート | `/*/templates` | GET |

### 工数管理API（Project Management）

| カテゴリ | 主要パス | 操作 |
|---------|---------|------|
| ユーザー | `/users/me` | GET |
| チーム | `/teams` | GET |
| 工数 | `/workloads` | GET, POST |
| 工数集計 | `/workload_summaries` | GET |
| プロジェクト | `/projects` | GET, POST |

### 販売API（Sales Management）

| カテゴリ | 主要パス | 操作 |
|---------|---------|------|
| 案件 | `/businesses` | GET, POST, PATCH |
| 受注 | `/sales_orders` | GET, POST, PATCH |
| 納品 | `/deliveries` | GET, POST, PATCH |
| 売上 | `/sales` | GET, POST, PATCH |
| マスタ | `/master/*` | GET（フェーズ、進捗、商品、従業員等） |

> **→ 請求書・工数・販売API詳細**: `references/invoice-pm-sales-api.md`

---

## レート制限

> **API別の詳細なレート制限は「API別ベースURL・レート制限」テーブルを参照。**

レート制限は事業所単位で適用される。同一事業所に対する複数アプリからのリクエストが合算される点に注意。

### HR APIレート制限ヘッダー

```
X-RateLimit-Limit: 10000       # 最大リクエスト数
X-RateLimit-Remaining: 9500    # 残りリクエスト数
X-RateLimit-Reset: 1700000000  # リセット時刻（Unix timestamp）
```

### 超過時の対応

- 会計API: HTTP 400（レート制限超過メッセージ）
- HR API: HTTP 429 → リトライ、過度のアクセスで HTTP 403 + **10分間クールダウン**
- リトライ: 指数バックオフ推奨（1s → 2s → 4s）
- 並列実行時はスレッド数を制限（逐次実行では通常超過しない）

---

## エラーハンドリング

### HTTPステータスコード

| コード | 意味 | 対応 |
|--------|------|------|
| 200 | OK | GET/PUT成功 |
| 201 | Created | POST成功（リソース作成） |
| 204 | No Content | DELETE成功 |
| 400 | Bad Request | パラメータ不正、レート制限超過 |
| 401 | Unauthorized | 認証失敗（サブコード確認） |
| 403 | Forbidden | アプリ権限不足 |
| 404 | Not Found | リソース不存在 |
| 429 | Too Many Requests | レート制限（HR API） |
| 500 | Internal Server Error | サーバー側エラー（リトライ推奨） |

### 401エラーサブコード

| コード | 原因 | 対応 |
|--------|------|------|
| `expired_access_token` | トークン期限切れ | リフレッシュトークンで更新 |
| `invalid_grant` | 認証情報不正（トークン二重使用等） | 再認可フロー |
| `user_do_not_have_permission` | ユーザー権限不足 | freee管理画面で権限確認 |
| `company_not_found` | 事業所ID不正 | company_id再取得 |
| `freee_plan_limit` | プラン制限 | プランアップグレード |
| `not_available_plan_limited_app` | プラン制限（アプリ） | 同上 |
| `source_ip_address_limit` | IP制限 | IP許可設定確認 |
| `re_authorization_required` | アプリ権限変更 | ユーザー再認可 |

### エラーレスポンス形式

```json
{
  "status_code": 401,
  "errors": [
    {
      "type": "status",
      "messages": ["Permission denied"],
      "codes": ["user_do_not_have_permission"]
    }
  ]
}
```

> **注意**: エラーメッセージは変更される可能性がある。`codes` フィールドで判定すること。新しいエラーコードも予告なく追加されるため、未知コードの汎用ハンドリングも実装すること。

### TypeScript: トークン自動リフレッシュパターン

```typescript
interface FreeeTokenSet {
  access_token: string;
  refresh_token: string;
  expires_at: number; // Unix timestamp
  company_id: string;
}

// ユーザー単位の排他制御（同一ユーザーの並行リフレッシュ防止）
const refreshLocks = new Map<string, Promise<FreeeTokenSet>>();

async function getValidToken(userId: string): Promise<FreeeTokenSet> {
  const token = await loadTokenFromDb(userId);
  if (Date.now() / 1000 <= token.expires_at - 300) return token;

  let lock = refreshLocks.get(userId);
  if (!lock) {
    lock = refreshFreeeToken(userId, token).finally(() => {
      refreshLocks.delete(userId);
    });
    refreshLocks.set(userId, lock);
  }
  return await lock;
}

async function freeeApiFetch<T>(
  url: string, userId: string, init: RequestInit = {}
): Promise<T | undefined> {
  const token = await getValidToken(userId);
  const headers = new Headers(init.headers);
  headers.set('Authorization', `Bearer ${token.access_token}`);
  headers.set('Accept', 'application/json');
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  const res = await fetch(url, { ...init, headers });
  if (res.status === 204) return undefined;     // DELETE成功等
  if (res.status === 401) {
    const body = await res.json();
    if (body.errors?.[0]?.codes?.includes('expired_access_token')) {
      // 排他制御付きリフレッシュ後にリトライ
      const newToken = await getValidToken(userId);
      headers.set('Authorization', `Bearer ${newToken.access_token}`);
      const retry = await fetch(url, { ...init, headers });
      if (retry.status === 204) return undefined;
      if (!retry.ok) throw await retry.json();
      return (await retry.json()) as T;
    }
    throw new Error(`freee API error: ${JSON.stringify(body)}`);
  }
  if (!res.ok) throw await res.json();
  return (await res.json()) as T;
}
```

---

## Webhook（Beta）

### 会計API Webhook

| リソース | イベント |
|---------|---------|
| 経費精算 (`accounting:expense_application`) | created, updated, destroyed |
| 各種申請 (`accounting:approval_request`) | created, updated, destroyed |
| 支払依頼 (`accounting:payment_request`) | created, updated, destroyed |

### HR API Webhook

| リソース | イベント |
|---------|---------|
| 従業員 (`hr:employee`) | created, updated, destroyed |

### 検証

リクエストヘッダー `x-freee-token` の値を、アプリのWebhook設定で表示される検証トークンと照合する。

### 制限事項（Beta）

- エラーログ未提供
- API経由のCRUD操作は通知対象外（Web画面操作のみ）
- HR: 一括インポート、退職処理は通知対象外
- ドメインホワイトリスト: `egw.freee.co.jp` の許可が必要

> **→ Webhook実装詳細・検証コード**: `references/webhook-setup.md`

---

## Developer Portal セットアップ

freeeアプリ作成・環境変数設定・コールバックURL登録・トラブルシューティングの完全ガイド。

> **→ 初回セットアップ・トラブルシューティング**: `references/developer-portal-setup.md`

---

## 開発ツール

### freee MCP Server（推奨）

Claude Desktop/Codeからfreee APIを直接操作できるMCPサーバー。5つのAPI全対応、72のリファレンスファイル。

```bash
# セットアップ
npx freee-mcp configure

# Claude Codeプラグイン
claude plugin install freee/freee-mcp
```

- OAuth 2.0 + PKCE認証（自動トークンリフレッシュ）
- GitHub: https://github.com/freee/freee-mcp
- Discord: https://discord.gg/9ddTPGyxPw

### OpenAPI Generator（クライアントコード自動生成）

公式SDKは全てARCHIVED。OpenAPI Generatorで任意言語のクライアントコードを生成する。

```bash
# TypeScriptクライアント生成例
docker run --rm -v "${PWD}:/local" \
  openapitools/openapi-generator-cli:v5.4.0 generate \
  -i https://raw.githubusercontent.com/freee/freee-api-schema/master/v2020_06_15/open-api-3/api-schema.json \
  -g typescript-fetch \
  -o /local/freee-client
```

### OpenAPIスキーマURL

| API | スキーマパス |
|-----|------------|
| 会計 | `v2020_06_15/open-api-3/api-schema.json` |
| HR | `hr/open-api-3/api-schema.json` |
| 請求書 | `iv/open-api-3/api-schema.json` |
| 工数管理 | `pm/open-api-3/api-schema.json` |
| 販売 | `sm/open-api-3/api-schema.json` |

ベースURL: `https://raw.githubusercontent.com/freee/freee-api-schema/master/`

---

## アプリ種別

| | Private App | Public App |
|---|---|---|
| 用途 | 自社利用 | 複数事業所・一般公開 |
| 事業所上限 | 5 | 20（ストア公開で無制限） |
| ストア掲載 | 不可 | 審査通過後に可能 |
| 口座明細 | 制限なし | セキュリティ審査必要 |
| 変更 | **作成後変更不可** | **作成後変更不可** |

### アプリ審査

- 所要時間: 約1-2週間
- アプリ名に "for freee" / "by freee" 使用禁止
- 事業所選択機能の実装必須（`prompt=select_company`）
- 最小権限の原則
- **権限追加時**: 全アクセストークンが破棄される → ユーザーの再認可が必要

---

## クイックスタート

### 1. 事業所一覧取得（company_id確認）

```bash
curl -s "https://api.freee.co.jp/api/1/companies" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"
```

### 2. 取引先一覧取得

```bash
curl -s "https://api.freee.co.jp/api/1/partners?company_id=${COMPANY_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"
```

### 3. HR: 従業員一覧取得

```bash
curl -s "https://api.freee.co.jp/hr/api/v1/companies/${COMPANY_ID}/employees" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"
```

### 4. 取引（支出）作成

```bash
curl -X POST "https://api.freee.co.jp/api/1/deals" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "company_id": '"${COMPANY_ID}"',
    "issue_date": "2026-03-26",
    "type": "expense",
    "details": [{
      "account_item_id": 101,
      "tax_code": 2,
      "amount": 10000,
      "description": "テスト取引"
    }]
  }'
```

---

## チェックリスト

### API呼び出し前
- [ ] company_idを取得・保持しているか
- [ ] マスタデータ（取引先・勘定科目・税区分）を同期済みか
- [ ] アクセストークンの有効期限を確認しているか
- [ ] HTTPSでリクエストしているか
- [ ] Content-Type: application/json を設定しているか

### レスポンス処理
- [ ] 未知のJSONプロパティを無視する設計か（後方互換）
- [ ] 401エラー時にサブコード（codes）で分岐しているか
- [ ] レート制限超過時のリトライ（指数バックオフ）を実装しているか
- [ ] ページネーションを考慮しているか（offset, limit）

### トークン管理
- [ ] リフレッシュ時に新しいリフレッシュトークンを保存しているか
- [ ] stateパラメータでCSRF対策しているか
- [ ] トークンをログや画面に露出させていないか
- [ ] リフレッシュトークン期限（90日）の管理・再認可フローがあるか

---

## トラブルシューティング

### Q: 401 `expired_access_token` が頻発する
A: アクセストークンは6時間で期限切れ。リフレッシュトークンでプロアクティブに更新する（期限の5分前など）。

### Q: 401 `invalid_grant` でリフレッシュが失敗する
A: リフレッシュトークンは1回使い切り。同一トークンを複数回使用すると失敗する。並行リクエスト時はトークンリフレッシュの排他制御が必要。

### Q: 401 `re_authorization_required` が返る
A: アプリの権限（スコープ）を変更した場合、全トークンが無効化される。ユーザーに再認可フローを案内する。

### Q: 429/403でレート制限に引っかかる
A: HR APIは403 + 10分間クールダウンの場合がある。X-RateLimit-Remaining ヘッダーを監視し、残り少なくなったら待機する。

### Q: `freee_plan_limit` エラーが返る
A: フリープランでは仕訳帳API等が利用不可。ユーザーのプランを確認し、利用可能なエンドポイントのみ呼び出す。

### Q: レスポンスに新しいフィールドが突然現れた
A: 正常動作。freeeは後方互換として新フィールドを予告なく追加する。未知プロパティを無視する設計にすること。

---

## 詳細リファレンス

- `references/oauth-flow.md` — OAuth 2.0認証フロー完全実装（Next.js API Route、トークンローテーション、事業所選択、OOBフロー）
- `references/accounting-api.md` — 会計API全31+エンドポイント詳細（パラメータ、マスタ同期、経費精算ワークフロー、インボイス制度）
- `references/hr-api.md` — 人事労務API全エンドポイント詳細（従業員CRUD、勤怠、打刻、認可レベル）
- `references/invoice-pm-sales-api.md` — 請求書・工数管理・販売API詳細（請求書移行注意、プロジェクト収支、販売マスタ）
- `references/webhook-setup.md` — Webhook設定・検証実装（イベント一覧、ペイロード形式、TypeScript検証コード）

> **動的読み込みルール**: references/ 配下のファイルは起動時に一括読み込みしない。必要に応じて該当ファイルのみ読み込むこと。

---

## 関連スキル

| スキル | 関連 |
|--------|------|
| `usacon` | freee会計データとの連携がある場合 |
| `stripe-cli` | Stripe決済 → freee取引自動作成パターン |
| `supabase-cli` | トークンストレージ（access/refresh token）をSupabaseに保存 |
| `gbizinfo` | 法人番号で企業情報を取得 → freee取引先マスタと連携 |

---

## 関連リソース

| リソース | URL |
|---------|-----|
| 開発者ポータル | https://developer.freee.co.jp/ |
| クイックスタート | https://developer.freee.co.jp/startguide |
| ベストプラクティス | https://developer.freee.co.jp/guideline |
| APIリファレンス | https://developer.freee.co.jp/reference |
| お知らせ | https://developer.freee.co.jp/info |
| OpenAPIスキーマ | https://github.com/freee/freee-api-schema |
| freee MCP | https://github.com/freee/freee-mcp |
| Postman | https://www.postman.com/freee-public-api/workspace/freee-public-api-workspace/ |

---

## 最近の変更（2025-2026）

| 時期 | 変更 |
|------|------|
| 2026年2月 | 販売APIに納品・売上の8エンドポイント追加 |
| 2025年12月 | 人事労務API: 特別休暇同日組み合わせ対応 |
| 2025年7月 | インボイス制度対応のAPI仕様変更 |
| 2025年5月 | ファイルボックスアップロードのレート制限を600→300に変更 |
| 2023年12月 | リフレッシュトークン有効期限を無期限→90日に変更 |
| 2023年4-10月 | インボイス制度対応（請求書API移行、税コード追加） |

---

## 改訂履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026-03-26 | 1.0.0 | 初版作成（5 API、OAuth、Webhook、開発ツール） |
| 2026-03-26 | 1.0.1 | Codexレビュー反映: API別ベースURL明示化、レート制限正確化、company_id記述修正、TypeScript排他制御修正、OpenAPIスキーマ表にPM追加 |
