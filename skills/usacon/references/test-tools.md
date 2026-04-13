# テストツール詳細（Playwright, Supabase, Vercel, Stripe）

> 元のSKILL.mdの「テスト時に使用するツール」セクション（Playwright MCP、Supabase MCP、Vercel MCP、Stripe CLI、テストアカウント）から抽出

> **MCPプラグイン**: Playwright, Supabase, Vercel
> **CLI（プラグインなし）**: Stripe CLI

## 1. Playwright MCPプラグイン（E2Eテスト・画面確認）
ブラウザを自動操作してUIテストを実行。

```
# ページにアクセス
mcp__plugin_playwright_playwright__browser_navigate
  url: https://usacon-ai.com

# ページ構造を取得（スクリーンショットより軽量）
mcp__plugin_playwright_playwright__browser_snapshot

# 要素をクリック（refはsnapshotから取得）
mcp__plugin_playwright_playwright__browser_click
  element: "ログアウトボタン"
  ref: "e19"

# 待機（ページロード待ち）
mcp__plugin_playwright_playwright__browser_wait_for
  time: 3

# スクリーンショット保存
mcp__plugin_playwright_playwright__browser_take_screenshot
  filename: "dashboard.png"
```

### snapshot vs screenshot 使い分け

| 状況 | 推奨ツール | 理由 |
|------|-----------|------|
| 通常の操作結果確認 | `browser_snapshot` | 軽量、テキスト検証可能、ref取得可能 |
| ドロワー/モーダル展開時 | `browser_take_screenshot` | 視覚的レイアウト確認が必要 |
| 50K超の大規模DOM | `browser_take_screenshot` | snapshotが巨大になりコンテキスト圧迫 |
| レイアウト崩れの検証 | `browser_take_screenshot` | テキストだけでは判断不可 |
| 次の操作のためのref取得 | `browser_snapshot` | screenshotからはrefを取得できない |

## 2. Supabase MCPプラグイン（データベース確認）
```bash
# テーブル一覧・サイズ確認
npx supabase inspect db table-sizes --linked

# APIキー取得
npx supabase projects api-keys --project-ref bpcpgettbblglikcoqux

# REST APIでデータ取得（Docker不要）
curl -s "https://bpcpgettbblglikcoqux.supabase.co/rest/v1/<table>?select=*" \
  -H "apikey: <SERVICE_ROLE_KEY>" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

## 3. Vercel MCPプラグイン（デプロイ確認）
```bash
# デプロイ状況確認
npx vercel ls digital-management-consulting-app --yes

# 最新デプロイの詳細
npx vercel inspect <deployment-url>
```

## 4. Stripe CLI（プラグインなし・決済テスト）
StripeにはMCPプラグインがないため、CLIを直接使用。

```bash
# ログイン
stripe login

# 顧客一覧
stripe customers list

# サブスクリプション一覧
stripe subscriptions list

# 商品・価格一覧
stripe products list
stripe prices list

# Webhookローカル転送（開発時）
stripe listen --forward-to localhost:5000/api/payment/webhook

# テストイベント送信
stripe trigger checkout.session.completed
stripe trigger customer.subscription.created
stripe trigger invoice.paid

# 最近のイベント確認
stripe events list --limit 10
```

**テストカード:**
| カード番号 | 結果 |
|-----------|------|
| 4242 4242 4242 4242 | 成功 |
| 4000 0000 0000 0002 | 拒否 |

## テストアカウント

> 詳細は [../checklist.md](../checklist.md) の「テストアカウント」セクションを参照

| プラン | メールアドレス | パスワード |
|--------|--------------|-----------|
| **無料** | `takeshitaseigyo@gmail.com` | `Password12345` |
| **スタンダード** | `robbits.develop@gmail.com` | `Robbits2025!` |
| **プロフェッショナル** | `ytakeshita@robbits.co.jp` | `password123` |
