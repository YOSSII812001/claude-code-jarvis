# freee Developer Portal セットアップガイド

## 全体フロー

```
1. freee開発者アカウント作成
2. テスト事業所 + テストアプリ作成
3. テスト環境でOAuth動作確認
4. 本番アプリ作成（必要に応じて）
5. Vercel等に環境変数設定
6. デプロイ + 動作確認
```

---

## Step 1: freee開発者アカウント作成

1. https://developer.freee.co.jp/ にアクセス
2. 「新規登録」または既存freeeアカウントでログイン
3. 開発者利用規約に同意

---

## Step 2: テスト事業所 + テストアプリ作成

### テスト事業所
- 初回ログイン時に「開発用テスト事業所とテストアプリを作成」ボタンが表示される
- テスト事業所はAPIテスト専用の仮想環境（本番データに影響なし）
- **3ヶ月に1度自動初期化される** — テストデータは定期的にリセットされる
- 事業所一覧: https://accounts.secure.freee.co.jp/companies

### テストアプリ
- テスト事業所作成と同時に自動作成される
- アプリ一覧: https://app.secure.freee.co.jp/developers/applications
- テストアプリでは**テスト事業所のみ**に接続可能（本番事業所には接続不可）

---

## Step 3: アプリ設定（テスト / 本番共通）

### アプリ管理画面
https://app.secure.freee.co.jp/developers/applications

### 確認・設定すべき項目

| 項目 | 場所 | 説明 |
|------|------|------|
| **Client ID** | アプリ詳細 → 基本情報 | OAuth認証で使用。環境変数 `FREEE_CLIENT_ID` に設定 |
| **Client Secret** | アプリ詳細 → 基本情報 | OAuth認証で使用。環境変数 `FREEE_CLIENT_SECRET` に設定 |
| **コールバックURL** | アプリ詳細 → コールバックURL | OAuth認証後のリダイレクト先。**完全一致必須** |
| **権限スコープ** | アプリ詳細 → 権限設定 | `read` が最低限必要 |

### コールバックURL設定の注意点

**最も多いトラブル原因。以下を厳守すること:**

1. **完全一致が必須**: freeeに登録するURLと、アプリから送信する `redirect_uri` が1文字でも違うとエラー
2. **wwwの有無を統一**: ブラウザがリダイレクトする先のドメインと一致させる
   - `usacon-ai.com` → `www.usacon-ai.com` にリダイレクトされる場合、`https://www.usacon-ai.com/api/connectors/freee/callback` を登録
3. **末尾スラッシュなし**: `https://www.usacon-ai.com/api/connectors/freee/callback` （末尾 `/` なし）
4. **HTTPSのみ**: HTTPは不可
5. **複数URL登録可能**: 本番 + preview + localhost を必要に応じて追加

**Usacon用コールバックURL例:**
```
本番:    https://www.usacon-ai.com/api/connectors/freee/callback
Preview: https://preview.usacon-ai.com/api/connectors/freee/callback
ローカル: http://localhost:5000/api/connectors/freee/callback
```

> freeeはコールバックURLを1つしか登録できない制約がある場合、本番URLを優先し、preview/localは別アプリとして作成する。

---

## Step 4: テストアプリ vs 本番アプリ

| 項目 | テストアプリ | 本番アプリ |
|------|------------|-----------|
| 作成方法 | 初回セットアップで自動作成 | アプリ一覧から「新規作成」 |
| 接続可能な事業所 | テスト事業所のみ | 全事業所（ユーザーが認可した事業所） |
| Client ID/Secret | テスト用（本番で使うと認証エラー） | 本番用 |
| コールバックURL | テスト用URL | 本番ドメイン |
| 審査 | 不要 | アプリストア公開時のみ必要（自社利用なら不要） |
| 用途 | 開発・検証 | 実運用 |

**重要**: テストアプリのClient IDを本番環境に設定すると、本番事業所への接続時に認証エラーになる。

### 本番アプリの作成手順

1. https://app.secure.freee.co.jp/developers/applications にアクセス
2. 「新しいアプリケーション」をクリック
3. アプリ情報を入力:
   - アプリ名: サービス名（例: UsaCon）
   - アプリタイプ: **Webアプリケーション**
   - コールバックURL: 本番URLを設定
4. 権限スコープを設定（最低限 `read`）
5. 作成後、Client ID と Client Secret をメモ

---

## Step 5: 環境変数の設定（Vercel）

### 必須環境変数（5つ）

| 変数名 | 値の例 | 説明 |
|--------|--------|------|
| `FREEE_CLIENT_ID` | `688497081495989` | freeeアプリのClient ID |
| `FREEE_CLIENT_SECRET` | `AbCdEf123456...` | freeeアプリのClient Secret |
| `FREEE_CALLBACK_URL` | `https://www.usacon-ai.com` | ベースURL（パス部分は含めない） |
| `FREEE_ENCRYPTION_KEY` | `a1b2c3...（64文字hex）` | トークン暗号化キー（下記で生成） |
| `ENABLE_FREEE_CONNECTOR` | `true` | フィーチャーフラグ |

### 暗号化キーの生成

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### FREEE_CALLBACK_URL の注意

- **ベースURLのみ設定**（パスは含めない）
- コード側で `/api/connectors/freee/callback` を自動付加する
- wwwリダイレクトがある場合は **www付き** で設定
- 末尾スラッシュは除去される（防御コード実装済み）

| NG | OK |
|----|-----|
| `https://usacon-ai.com` （wwwなし） | `https://www.usacon-ai.com` |
| `https://www.usacon-ai.com/` （末尾/） | `https://www.usacon-ai.com` |
| `https://www.usacon-ai.com/api/connectors/freee/callback` | `https://www.usacon-ai.com` |

### Vercel CLI での設定

```bash
# 各環境変数を全環境（Production/Preview/Development）に追加
vercel env add FREEE_CLIENT_ID
vercel env add FREEE_CLIENT_SECRET
vercel env add FREEE_CALLBACK_URL
vercel env add FREEE_ENCRYPTION_KEY
vercel env add ENABLE_FREEE_CONNECTOR

# 設定確認
vercel env ls | grep -i freee
```

### 環境変数設定後の注意

- Vercelの環境変数は**次回デプロイから反映**（既存デプロイには反映されない）
- 設定変更後は再デプロイが必要: `vercel --prod` またはコードプッシュ

---

## Step 6: 動作確認チェックリスト

### 事前確認（デプロイ前）

- [ ] freee Developersでアプリが作成されている
- [ ] コールバックURLが正しく登録されている（www有無、パス、HTTPSを確認）
- [ ] Client ID / Secret が正しい（テスト用と本番用を混同していないか）
- [ ] Vercelに5つの環境変数が全て設定されている
- [ ] 再デプロイ済み（環境変数変更後）

### 動作確認（デプロイ後）

- [ ] コネクタページ（/connectors）が表示される
- [ ] 「接続する」ボタン押下でfreee OAuth画面に遷移する
- [ ] OAuth画面のURLに正しいclient_id, redirect_uriが含まれている
- [ ] freeeで認可後、アプリにリダイレクトされる
- [ ] コネクタステータスが「接続済み」に変わる
- [ ] ブラウザコンソールにエラーがない

---

## トラブルシューティング

### 「接続する」押下で何も起きない / エラー

| 症状 | 原因 | 対処 |
|------|------|------|
| 401 Unauthorized | フロントのAuthorizationヘッダーに無効トークンが送信されている | Issue #1598 の修正を確認（非JWTトークンフィルタ） |
| OAuth画面が表示されない | `FREEE_CLIENT_ID` が未設定 or 空 | Vercel env ls で確認 |
| OAuth画面でエラー | Client IDがテスト用 / 無効 | freee Developersでアプリ状態を確認 |

### OAuth認可後にエラー（コールバックで401）

| 症状 | 原因 | 対処 |
|------|------|------|
| コールバックURLで401 Unauthorized | **Express Routerマウントパスの二重化**。`app.get('/full/path', router)` ではルーター内パスとマウントパスが合算されマッチしない | PR #1605 で修正済み。`app.use()` 内で `req.path` 判定して認証スキップする方式を使用 |
| `redirect_uri_mismatch` | コールバックURLの不一致 | freee登録URLとFREEE_CALLBACK_URL+パスの完全一致を確認 |
| `invalid_client` | Client Secret が間違っている | freee Developersで再確認、Vercel env を再設定 |
| `invalid_grant` | 認可コード期限切れ or 二重使用 | 再度OAuth認可フローを実施 |

### 「接続中...」が永続する

| 症状 | 原因 | 対処 |
|------|------|------|
| OAuthウィンドウを閉じた後に「接続中...」が残る | stale connecting状態 | Issue #1600 のread-repair修正を確認。10分後に自動復帰 |
| 初回表示から「接続中...」 | DBに古いconnecting レコードが残存 | ページリロードでread-repairが発動 |

### 環境変数の確認コマンド

```bash
# Vercelの設定確認
vercel env ls | grep -i freee

# ローカル .env への取り込み
vercel env pull .env.local
grep FREEE .env.local
```

---

## Usacon固有の実装メモ

- フィーチャーフラグ: `ENABLE_FREEE_CONNECTOR`（`api/_lib/config/claude.js`）
- コネクタサービス: `api/_lib/services/freeeConnectorService.js`
- コネクタルート: `api/_lib/routes/freeeConnector.js`
- フロントエンド: `frontend/src/pages/account/Connectors.tsx`
- APIクライアント: `frontend/src/services/connectorService.ts`
- DBテーブル: `user_connectors`（マイグレーション: `20260326000000_create_user_connectors.sql`）
- トークン暗号化: `api/_lib/utils/tokenEncryption.js`（AES-256-GCM）

### コネクタAPIエンドポイント

| メソッド | パス | 認証 | 説明 |
|---------|------|------|------|
| GET | `/api/connectors` | 要 | コネクタ一覧取得 |
| POST | `/api/connectors/freee/authorize` | 要 | OAuth認可URL生成 |
| GET | `/api/connectors/freee/callback` | 不要 | OAuthコールバック |
| POST | `/api/connectors/freee/validate` | 要 | 接続検証 |
| POST | `/api/connectors/freee/disconnect` | 要 | 接続解除 |

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-03-27 | 初版作成。Issue #1598/#1600 教訓からコールバックURL注意点、環境変数チェックリスト、トラブルシューティングを整備 |
