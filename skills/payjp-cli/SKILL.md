---
name: PAY.JP CLI Operations
description: |
  PAY.JP決済の開発・テストにPAY.JP CLIを使用。Webhook開発、決済フロー検証、PayPay連携テストなど。
  トリガー: "payjp", "pay.jp", "PAY.JP", "payjp-cli", "payjp決済", "PayPay決済"
---

# PAY.JP CLI ガイド

## 概要
PAY.JP決済機能の開発・テストにはPAY.JP CLI（payjp-cli）を使用してください。
現在はWebhookイベントのローカル受信機能を提供。テストモード専用。

## インストール確認
```bash
payjp-cli --version
```

インストールされていない場合：
```bash
# Windows (scoop)
scoop bucket add payjp https://github.com/payjp/scoop-bucket.git
scoop install payjp-cli

# macOS (Homebrew)
brew install payjp/tap/payjp-cli

# その他: GitHub Releasesからバイナリ取得
# https://github.com/payjp/payjp-cli/releases
```

## 基本コマンド

### 認証
```bash
# ログイン（ブラウザ認証、ペアリングコード表示）
payjp-cli login

# プロファイル指定（複数アカウント管理）
payjp-cli login --profile my-project
```

### Webhook開発（主要機能）
```bash
# ローカルWebhookリスナー起動（ターミナル表示のみ）
payjp-cli listen

# ローカルサーバーへ転送
payjp-cli listen --forward-to http://localhost:3000/api/webhooks/payjp

# 特定イベントのみフィルタ
payjp-cli listen --events payment_flow.succeeded,setup_flow.succeeded --forward-to http://localhost:3000/api/webhooks/payjp

# プロファイル指定
payjp-cli listen --forward-to http://localhost:3000/api/webhooks/payjp --profile my-project
```

## PAY.JP v2 API リソース

### 主要リソース
| リソース | 説明 | プレフィックス |
|---------|------|---------------|
| Payment Flow | 決済フロー（v2中核） | `pf_` |
| Setup Flow | 支払い方法登録フロー | `sf_` |
| Payment Method | 支払い方法（カード等） | `pm_` |
| Customer | 顧客 | `cus_` |
| Product | 商品 | `prod_` |
| Price | 価格 | `price_` |
| Refund | 返金 | `re_` |

### 主要エンドポイント
```
# Payment Flow（決済）
POST   /v2/payment_flows           # 作成
GET    /v2/payment_flows/{id}      # 取得
POST   /v2/payment_flows/{id}/confirm  # 確認
POST   /v2/payment_flows/{id}/capture  # 確定
POST   /v2/payment_flows/{id}/cancel   # キャンセル

# Setup Flow（支払い方法登録）
POST   /v2/setup_flows             # 作成
GET    /v2/setup_flows/{id}        # 取得
POST   /v2/setup_flows/{id}/confirm    # 確認
POST   /v2/setup_flows/{id}/cancel     # キャンセル

# Payment Method
POST   /v2/payment_methods         # 作成（テストモードのみ）
GET    /v2/payment_methods         # 一覧
GET    /v2/payment_methods/{id}    # 取得
POST   /v2/payment_methods/{id}    # 更新
POST   /v2/payment_methods/{id}/attach  # 顧客に紐付け
POST   /v2/payment_methods/{id}/detach  # 顧客から削除

# Customer / Product / Price
POST   /v2/customers               # 顧客作成
GET    /v2/customers               # 一覧
POST   /v2/products                # 商品作成
POST   /v2/prices                  # 価格作成
```

### 認証方法
```bash
# HTTP Basic Auth（テストキー）
curl https://api.pay.jp/v2/payment_flows \
  -u sk_test_xxxxxxxxxxxxxxxxxxxx:

# HTTP Bearer Auth
curl https://api.pay.jp/v2/payment_flows \
  -H "Authorization: Bearer sk_test_xxxxxxxxxxxxxxxxxxxx"
```

**キー形式:**
| キー | 用途 |
|------|------|
| `pk_test_` | テスト公開キー（クライアント側） |
| `sk_test_` | テストシークレットキー（サーバー側） |
| `pk_live_` | 本番公開キー |
| `sk_live_` | 本番シークレットキー |

## Webhookイベント一覧

### Payment Flow イベント
| イベント | 説明 |
|---------|------|
| `payment_flow.created` | 決済フロー作成 |
| `payment_flow.succeeded` | 決済成功 |
| `payment_flow.canceled` | 決済キャンセル |
| `payment_flow.payment_failed` | 決済失敗 |
| `payment_flow.requires_action` | 3Dセキュア等の追加認証必要 |
| `payment_flow.processing` | 処理中 |
| `payment_flow.amount_capturable_updated` | キャプチャ可能額変更 |

### Setup Flow イベント
| イベント | 説明 |
|---------|------|
| `setup_flow.created` | セットアップ作成 |
| `setup_flow.succeeded` | セットアップ完了 |
| `setup_flow.canceled` | キャンセル |
| `setup_flow.requires_action` | 追加認証必要 |
| `setup_flow.setup_failed` | セットアップ失敗 |

### Payment Method イベント
| イベント | 説明 |
|---------|------|
| `payment_method.attached` | 顧客に紐付け |
| `payment_method.detached` | 顧客から削除 |
| `payment_method.updated` | 更新 |

### Checkout イベント
| イベント | 説明 |
|---------|------|
| `checkout.session.completed` | チェックアウト完了 |
| `checkout.session.expired` | セッション期限切れ |

### Customer イベント
| イベント | 説明 |
|---------|------|
| `customer.created` | 顧客作成 |
| `customer.updated` | 顧客更新 |
| `customer.deleted` | 顧客削除 |

### Refund / Catalog / Financial イベント
| イベント | 説明 |
|---------|------|
| `refund.created` / `updated` / `failed` | 返金関連 |
| `product.created` / `updated` / `deleted` | 商品関連 |
| `price.created` / `updated` / `deleted` | 価格関連 |
| `tax_rate.created` / `updated` | 税率関連 |
| `dispute.created` | チャージバック |
| `term.created` / `closed` | 精算期間 |
| `statement.created` | 取引明細 |
| `balance.created` / `fixed` / `closed` / `merged` | 残高関連 |

## Webhook実装ガイド

### ヘッダー構造
```
Content-Type: application/json; charset=utf-8
X-Payjp-Webhook-Token: whook_xxxxxxxxxxxxx
```

### ⚠️ Webhook実装の重要ポイント
- **応答**: 10秒以内に 2xx を返すこと
- **リトライ**: 非2xx応答は3分間隔で最大3回リトライ
- **検証**: `X-Payjp-Webhook-Token` ヘッダーのトークンをダッシュボードの値と照合
- **Stripeとの違い**: Stripeはsigning secret + HMAC署名検証だが、PAY.JPはトークン一致検証

### Webhook開発フロー
1. `payjp-cli listen --forward-to http://localhost:3000/api/webhooks/payjp` 起動
2. ダッシュボードでWebhookトークンを確認し環境変数に設定
3. ローカルでイベント処理を実装・テスト

## テストカード

### 成功するカード
| カード番号 | ブランド |
|-----------|---------|
| 4242 4242 4242 4242 | Visa |
| 4012 8888 8888 1881 | Visa |
| 5555 5555 5555 4444 | Mastercard |
| 5105 1051 0510 5100 | Mastercard |
| 3530 1113 3330 0000 | JCB |
| 3566 0020 2036 0505 | JCB |
| 3782 822463 10005 | American Express |
| 3714 496353 98431 | American Express |
| 3852 0000 0232 37 | Diners Club |
| 3056 9309 0259 04 | Diners Club |
| 6011 1111 1111 1117 | Discover |
| 6011 0009 9013 9424 | Discover |

### 海外発行カード
| カード番号 | ブランド |
|-----------|---------|
| 4000 0009 0000 0003 | Visa（海外） |

### エラーを返すカード（支払い作成時）
| カード番号 | 用途 |
|-----------|------|
| 4000 0000 0000 0002 | 汎用拒否 |
| 4000 0000 0000 0069 | 有効期限エラー |
| 4000 0000 0000 0127 | CVCエラー |
| 4000 0000 0000 0119 | 処理エラー |
| 4000 0000 0000 3720 | 不正検知 |
| 3622 7206 2716 67 | カード会社拒否 |

### エラーを返すカード（支払い時）
| カード番号 | 用途 |
|-----------|------|
| 4000 0000 0008 0319 | 支払い拒否 |
| 4000 0000 0000 4012 | 金額超過 |
| 4000 0000 0008 0202 | タイムアウト |
| 4000 0000 0000 0077 | 処理失敗 |

### 特定ステータスカード
| カード番号 | 用途 |
|-----------|------|
| 4000 0000 0000 0036 | 保留 |
| 4000 0000 0000 0101 | レビュー |
| 4000 0000 0000 0044 | ブロック |

## 対応決済方法
| 方法 | 状態 | 備考 |
|------|------|------|
| クレジット/デビットカード | ✅ GA | Visa/MC/JCB/Amex/Diners/Discover |
| PayPay | ✅ GA | QRコード決済（Usacon導入予定） |
| Apple Pay | ✅ GA | iOS/Safari |

## エラーコード
| コード | HTTPステータス | 説明 |
|--------|---------------|------|
| `validation_error` | 422 | リクエスト検証失敗 |
| `not_found` | 404 | リソース未検出 |
| `invalid_apple_pay_token` | 400 | Apple Payトークン無効 |
| `payment_method_already_attached` | 400 | 既に紐付け済み |
| `invalid_status` | 400 | 無効なステータス遷移 |
| `metadata_limit_exceeded` | 400 | メタデータ上限超過（最大20項目） |
| Payment Failed | 402 | 決済失敗 |

## Stripe → PAY.JP 移行のマッピング

Usaconで将来Stripe併用/移行する際の参考：

| Stripe | PAY.JP v2 | 備考 |
|--------|-----------|------|
| `PaymentIntent` | `Payment Flow` | ステータス遷移も類似 |
| `SetupIntent` | `Setup Flow` | 支払い方法の事前登録 |
| `PaymentMethod` | `Payment Method` | カード・PayPay等 |
| `Customer` | `Customer` | 同一概念 |
| `Product` / `Price` | `Product` / `Price` | 同一概念 |
| `Refund` | `Refund` | 同一概念 |
| `stripe listen` | `payjp-cli listen` | Webhook転送 |
| `stripe trigger` | *(未対応)* | PAY.JP CLIにはtrigger機能なし |
| Signing Secret + HMAC | Webhook Token照合 | 検証方式が異なる |
| `stripe customers list` | `curl -u sk_test_:` | PAY.JP CLIにはリソース操作コマンドなし |

## チェックリスト

- [ ] テストモード（`sk_test_`）で実行しているか確認したか
- [ ] `payjp-cli listen` がローカルで起動中か
- [ ] Webhookトークン検証が実装されているか
- [ ] メタデータは20項目以内に収まっているか
- [ ] 10秒以内に2xx応答を返しているか
- [ ] 3Dセキュア（`requires_action`）ハンドリングが実装されているか

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `payjp-cli login` が失敗 | 認証トークン期限切れ | ブラウザで再認証 |
| Webhookイベントが届かない | `payjp-cli listen` 未起動 | `payjp-cli listen --forward-to ...` を起動 |
| テスト決済が拒否される | 本番キー使用 | `sk_test_` キーに切り替え |
| 本番イベントが受信できない | CLIはテストモード専用 | 本番Webhookはダッシュボードで設定 |
| 複数アカウント切替 | プロファイル未設定 | `--profile` オプションを使用 |
| `trigger` コマンドが見つからない | PAY.JP CLIは未対応 | ダッシュボードまたはAPIで直接テストイベント作成 |

## 関連スキル

- **stripe-cli** — Stripe決済操作（現在のUsacon決済基盤）
- **usacon** — 決済統合の実プロジェクト

## 参考
- PAY.JP v2 ドキュメント: https://docs.pay.jp/v2/guide
- PAY.JP v2 APIリファレンス: https://docs.pay.jp/v2/api
- PAY.JP CLI GitHub: https://github.com/payjp/payjp-cli
- PAY.JP CLI ガイド: https://docs.pay.jp/v2/guide/developers/payjp-cli

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-07 | 初版作成 | Usacon将来のPayPay決済導入に備えたPAY.JP CLIスキル |
