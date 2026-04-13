---
name: Stripe CLI Operations
description: |
  Stripe決済の開発・テストにStripe CLIを使用。Webhook開発、イベントトリガー、リソース管理など。
  PayPay決済の実装時は stripe-paypay サブスキルを動的参照。
  トリガー: "stripe", "決済", "webhook", "サブスクリプション", "課金", "PayPay", "paypay"
---

# Stripe CLI ガイド

## 概要
Stripe決済機能の開発・テストにはStripe CLIを使用してください。

## インストール確認
```bash
stripe --version
```

インストールされていない場合：
```bash
# Windows (scoop)
scoop install stripe

# macOS
brew install stripe/stripe-cli/stripe

# npm
npm install -g stripe
```

## 基本コマンド

### 認証
```bash
# ログイン（ブラウザ認証）
stripe login

# APIキー確認
stripe config --list
```

### Webhook開発（重要）
```bash
# ローカルWebhookリスナー起動
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# 特定イベントのみ転送
stripe listen --events checkout.session.completed,invoice.paid --forward-to localhost:3000/api/webhooks/stripe
```

### イベントトリガー（テスト用）
```bash
# チェックアウト完了イベント
stripe trigger checkout.session.completed

# サブスクリプション作成
stripe trigger customer.subscription.created

# 支払い成功
stripe trigger payment_intent.succeeded

# 請求書支払い
stripe trigger invoice.paid
```

### リソース操作
```bash
# 顧客一覧
stripe customers list

# 商品一覧
stripe products list

# 価格一覧
stripe prices list

# サブスクリプション一覧
stripe subscriptions list
```

### リソース作成
```bash
# 商品作成
stripe products create --name="Pro Plan" --description="プロプラン"

# 価格作成（月額）
stripe prices create \
  --product=prod_xxx \
  --unit-amount=1980 \
  --currency=jpy \
  --recurring-interval=month

# 顧客作成
stripe customers create --email="test@example.com"
```

### ログ確認
```bash
# 最近のイベント
stripe events list --limit 10

# 特定イベント詳細
stripe events retrieve evt_xxx

# APIリクエストログ
stripe logs tail
```

## Webhook開発フロー
1. `stripe listen --forward-to localhost:3000/api/webhooks/stripe` 起動
2. 表示されるWebhook Signing Secretを環境変数に設定
3. `stripe trigger <event>` でテストイベント送信
4. ローカルサーバーでイベント処理を確認

## 主要Webhookイベント
| イベント | 用途 |
|---------|------|
| `checkout.session.completed` | Checkout完了時 |
| `customer.subscription.created` | サブスク開始 |
| `customer.subscription.updated` | プラン変更 |
| `customer.subscription.deleted` | サブスク解約 |
| `invoice.paid` | 請求書支払い完了 |
| `invoice.payment_failed` | 支払い失敗 |

## テストカード
| カード番号 | 結果 |
|-----------|------|
| 4242 4242 4242 4242 | 成功 |
| 4000 0000 0000 0002 | 拒否 |
| 4000 0000 0000 3220 | 3Dセキュア |

## Portal Configuration管理

### 設定の確認
```bash
# 現在のPortal Configuration一覧
stripe billing_portal configurations list

# 特定のConfiguration詳細
stripe billing_portal configurations retrieve bpc_xxx
```

### 設定の作成
```bash
# Portal Configuration作成（proration_behaviorを明示的に指定）
stripe billing_portal configurations create \
  --features.subscription_update.enabled=true \
  --features.subscription_update.proration_behavior=create_prorations \
  --features.subscription_update.default_allowed_updates[0]=price \
  --features.subscription_cancel.enabled=true \
  --business_profile.headline="サブスクリプション管理"
```

### 設定の更新
```bash
# 既存Configurationのproration_behaviorを変更
stripe billing_portal configurations update bpc_xxx \
  --features.subscription_update.proration_behavior=create_prorations
```

### ⚠️ proration_behavior の注意

**Customer Portal Configuration の `proration_behavior` デフォルトは `none`（日割りなし）。**
Subscription API の `stripe.subscriptions.update` のデフォルト（`create_prorations`）とは異なる。

| APIレイヤー | デフォルト | 安全性 |
|------------|-----------|--------|
| `subscriptions.update` | `create_prorations` | 安全 |
| `billing_portal.configurations` | `none` | **危険** |

Portal経由のプラン変更で日割り計算が適用されず、**請求漏れが発生するリスクがある**。
必ず `proration_behavior: 'create_prorations'` を明示的に設定すること。

## ベストプラクティス
1. 開発中は必ず `stripe listen` でWebhookをローカル転送
2. テストモード（`sk_test_`）で十分にテスト
3. Webhook署名検証は必須（セキュリティ）
4. 冪等性キーを使用して重複処理を防止
5. **重要な課金パラメータは明示的に設定する**（暗黙のデフォルトに依存しない。特に `proration_behavior` はAPIレイヤーでデフォルトが異なる）

## チェックリスト

- [ ] テストモード（`sk_test_`）で実行しているか確認したか
- [ ] Webhook署名検証が実装されているか
- [ ] `stripe listen` がローカルで起動中か
- [ ] 冪等性キーを使用しているか

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `stripe login` が失敗 | 認証トークン期限切れ | ブラウザで再認証 |
| Webhookイベントが届かない | `stripe listen` 未起動 | `stripe listen --forward-to ...` を起動 |
| `signing_secret` 不一致 | listen再起動でsecret変更 | 新しいsecretを環境変数に再設定 |
| テスト決済が拒否される | 本番キー使用 | `sk_test_` キーに切り替え |
| `stripe trigger` でエラー | CLIバージョン古い | `scoop update stripe` で更新 |
| Portal経由のプラン変更で日割りが適用されない | Portal Configの `proration_behavior` がデフォルト `none` | `proration_behavior: 'create_prorations'` を明示設定 |

## PayPay 決済（Stripe経由）

PayPay決済の実装時は **stripe-paypay** サブスキルを参照すること。

### クイックスタート
1. Stripeダッシュボードで PayPay を有効化
2. `automatic_payment_methods` が有効なら **コード変更不要**
3. 手動指定: `payment_method_types: ['card', 'paypay']`

### 主な制約
- **JPY / JP のみ**（50〜1,000,000 JPY）
- **サブスクリプション非対応** → ワンタイム決済のみ
- **手動キャプチャー非対応**
- 詳細は `~/.claude/skills/stripe-paypay/SKILL.md` を参照

### テスト
```bash
# PayPay付きPaymentIntent作成
stripe payment_intents create \
  --amount=1000 --currency=jpy \
  -d "payment_method_types[]=paypay"
```

## 関連スキル

- **stripe-paypay** — PayPay決済のAPI仕様・実装パターン・制約事項リファレンス（サブスキル）
- **payjp-cli** — PAY.JP CLIリファレンス（参考資料、Stripe PayPayが推奨）
- **usacon** — Stripe決済統合の実プロジェクト
  - `references/stripe-pricing.md` — 料金プラン・環境変数・Price ID一覧
  - `references/stripe-portal-proration.md` — **Portal Configuration & 日割り計算（proration）ガイド**（#1434/#1435教訓）
- **supabase-cli** — billingスキーマとの連携

## 参考
- 公式ドキュメント: https://stripe.com/docs/cli
- Webhookガイド: https://stripe.com/docs/webhooks

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-16 | Portal Configuration管理セクション追加、proration_behavior注意事項、トラブルシューティング追記 | Issue #1434 教訓反映 |
| 2026-03-04 | 横断テンプレート適用（トリガー、チェックリスト、トラブルシューティング、関連スキル、改訂履歴追加） | スキル品質改善計画 |
| 2026-02-15 | 初版作成 | Stripe CLI操作の標準化 |
