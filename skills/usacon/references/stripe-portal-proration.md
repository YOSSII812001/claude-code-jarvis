# Stripe Portal Configuration & 日割り計算（Proration）ガイド

> Issue #1434, #1435 の教訓から作成。Portal Configuration と Webhook の proration/リセット日に関する罠と対策。

## 1. proration_behavior の APIレイヤー別デフォルト値の罠

**最重要**: 同じStripeでも APIレイヤーによって proration_behavior のデフォルト値が異なる。

| APIレイヤー | パラメータ | デフォルト値 | 影響 |
|------------|-----------|-------------|------|
| `stripe.subscriptions.update()` | `proration_behavior` | `create_prorations` | 日割り計算あり（安全） |
| `stripe.billingPortal.configurations` | `proration_behavior` | **`none`** | **日割り計算なし（危険）** |
| `stripe.checkout.sessions.create()` | - | 新規作成のため該当なし | - |

### 実際の被害（Issue #1434）

- Standard (¥70,000/月) → Professional (¥200,000/月) へCustomer Portal経由でアップグレード
- クレジット（機能面）は即時反映されたが、**差額約¥130,000が請求されなかった**
- 原因: `setup-stripe-portal-configs.js` で `proration_behavior` を指定していなかった → デフォルト `none` が適用

### 修正内容

```javascript
// api/scripts/setup-stripe-portal-configs.js
subscription_update: {
    enabled: true,
    default_allowed_updates: ['price'],
    products,
    proration_behavior: 'create_prorations', // ← 必ず明示指定
},
```

## 2. proration_behavior の3つのオプション

| 値 | 動作 | Invoice | ユースケース |
|----|------|---------|-------------|
| `none` | 日割り計算なし | 変化なし | **非推奨**（請求漏れリスク） |
| `create_prorations` | 日割り計算あり、次回請求にまとめる | 次回Invoice に proration line item 追加 | **推奨（月額プラン）** |
| `always_invoice` | 日割り計算あり、即時Invoice発行 | 即時に新しいInvoice発行 + 請求 | 年額プラン（最大11ヶ月の請求遅延を防ぐ場合）|

### create_prorations vs always_invoice

```
create_prorations:
  3/15: Standard→Professional にアップグレード
  3/15: proration line item 生成（差額 ¥130,000）
  4/15: 次回請求日に ¥130,000（差額）+ ¥200,000（次月分）= ¥330,000 請求

always_invoice:
  3/15: Standard→Professional にアップグレード
  3/15: 即時Invoice発行、差額 ¥130,000 を即時請求
  4/15: 次回請求日に ¥200,000（次月分）のみ請求
```

**注意**: `always_invoice` に変更する場合、`payment.js` の `billing_reason` フィルタ（L996付近）で `subscription_update` が `allowedReasons` に含まれているか確認が必要。

## 3. Portal Configuration セットアップスクリプト

### スクリプトの役割

`api/scripts/setup-stripe-portal-configs.js` は Customer Portal の Configuration を作成/更新する。
upsert ロジック（metadata.usacon_type で検索）により、**既存の Configuration ID を維持したまま設定を更新**できる。

### 実行手順

```bash
# テスト環境（.env.preview の変数を使用）
cd <project_root>
set -a && source .env.preview && set +a
cd api && node scripts/setup-stripe-portal-configs.js

# 本番環境（Vercelから環境変数を取得して使用）
cd <project_root>
npx vercel env pull .env.production.local --environment production --yes
set -a && source .env.production.local && set +a
cd api && node scripts/setup-stripe-portal-configs.js
rm -f .env.production.local  # セキュリティ: 本番キーを残さない
```

### 実行が必要なタイミング

- Portal Configuration のパラメータを変更した時（コードデプロイだけではStripe側は更新されない）
- 新しい Product/Price を追加した時
- proration_behavior を変更した時

### 現在の Configuration ID

| 環境 | usacon_type | Configuration ID |
|------|------------|-----------------|
| テスト | standard | `bpc_1TBStMQWzpid7on2x9jIhuNx` |
| テスト | professional | `bpc_1TBStNQWzpid7on2aoHTnGZ1` |
| 本番 | standard | `bpc_1TBStnHbOWA7CJ3RRf5rorSf` |
| 本番 | professional | `bpc_1TBStoHbOWA7CJ3R8sBSE18z` |

## 4. next_reset_at 計算の罠（Issue #1435）

### 問題

月額プランの `invoice.paid` (billing_reason=subscription_cycle) で、次回リセット日を計算する際に:

```javascript
// ❌ バグ: periodEndDate を「現在時刻」として渡すと1か月ズレる
nextResetAt = computeNextResetAtFromAnchor(periodStartDate, periodEndDate)?.toISOString();
```

`computeNextResetAtFromAnchor` は第2引数を「現在時刻」として扱い、「nowの後の次のリセット日」を返す。
`periodEndDate`（= 次回リセット日そのもの）を渡すと、その日以降 = 翌月のリセット日が返される。

### 修正

```javascript
// ✅ 正解: Stripe の period.end をそのまま使用（月末日丸めも処理済み）
nextResetAt = periodEndDate.toISOString();
```

### 教訓

- **Stripe が正確な値を返す場合、クライアント側で再計算しない**
- Stripe の `period.end` は月末日丸め（31日→28日等）を正しく処理済み
- `computeNextResetAtFromAnchor` は Cron等の「現在時刻から次回を算出」するケースに限定して使用

### next_reset_at の全更新経路

| # | ハンドラ | 計算方法 | 状態 |
|---|---------|---------|------|
| 1 | handleCheckoutSessionCompleted | `computeNextResetAtFromStripeAnchor(billing_cycle_anchor)` | ✅正常 |
| 2 | handleSubscriptionCreated | `computeNextResetAtFromStripeAnchor(anchorSeconds)` | ✅正常 |
| 3 | handleInvoicePaymentSucceeded (subscription_create) | `computeNextResetAtFromStripeAnchor(linePeriodStart)` | ✅正常 |
| 4 | handleInvoicePaymentSucceeded (subscription_cycle, 月額) | `periodEndDate.toISOString()` | ✅修正済み(#1435) |
| 5 | handleInvoicePaymentSucceeded (subscription_cycle, 年額) | `computeNextResetAtFromStripeAnchor(linePeriodStart)` | ✅正常 |
| 6 | handleSubscriptionUpdated | `computeNextResetAtFromStripeAnchor(anchorSeconds)` | ✅正常 |
| 7 | resetCreditsMonthly (Cron) | `computeNextResetAtFromAnchor(anchorDate, now)` | ⚠️要注意 |

## 5. チェックリスト

### Portal Configuration 変更時
- [ ] `proration_behavior` を明示的に指定しているか
- [ ] テスト環境でスクリプト実行 → Stripeダッシュボードで確認
- [ ] 本番環境でスクリプト実行 → Stripeダッシュボードで確認
- [ ] `.env.production.local` を削除したか（セキュリティ）

### Webhook ハンドラ変更時（next_reset_at 関連）
- [ ] 上記「全更新経路」のうち、変更した経路を特定
- [ ] Stripe の値をそのまま使えるか、再計算が必要か判断
- [ ] payment.test.js で保存値を固定するテストがあるか確認

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `api/scripts/setup-stripe-portal-configs.js` | Portal Configuration upsert スクリプト |
| `api/_lib/routes/payment.js` | Webhook ハンドラ（next_reset_at 計算含む） |
| `api/_lib/utils/creditResetDate.js` | `computeNextResetAtFromAnchor` / `computeNextResetAtFromStripeAnchor` |
| `api/_lib/routes/payment.test.js` | Webhook テスト |

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-16 | 初版作成 | Issue #1434 (proration_behavior) + #1435 (next_reset_at) の教訓 |
