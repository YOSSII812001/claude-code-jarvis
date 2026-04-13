---
name: Stripe PayPay決済
description: |
  Stripe経由でPayPay決済を実装するためのAPI仕様・実装パターン・制約事項リファレンス。
  stripe-cliメインスキルから動的に参照される。直接トリガーされない。
---

# Stripe PayPay 決済リファレンス

## 概要
StripeのPayment Methods APIでPayPayをネイティブサポート。既存のStripe基盤にPayPayを追加するだけで、QRコード決済を受け付けられる。

## 制約事項（重要）

| 項目 | 値 |
|------|-----|
| ビジネス所在地 | JP（日本）のみ |
| 対応通貨 | JPY のみ |
| 最小請求額 | 50 JPY |
| 最大請求額 | 1,000,000 JPY |
| 継続課金（サブスクリプション） | **非対応** |
| セットアップモード | **非対応** |
| 手動キャプチャー | **非対応** |
| Connect | **非対応** |
| 不審請求の申し立て | **非対応** |
| Express Checkout Element | **非対応** |
| 返金 / 一部返金 | 対応（即時完了、最大365日） |
| 決済手段の種類 | ウォレット（リダイレクトベース） |

### 禁止業種
- 暗号資産取引所とウォレット
- PayPayの判断による他のカテゴリー

## 有効化手順
1. Stripeダッシュボード → 決済手段設定
2. PayPayを有効化
3. `payment_method_types` に `'paypay'` を追加、または自動決済手段（`automatic_payment_methods`）を利用

## 対応Stripeプロダクト

| プロダクト | 対応 | 備考 |
|-----------|------|------|
| Payment Links | ✅ | ダッシュボードから追加 |
| Checkout | ✅ | paymentモードのみ（subscription/setupは非対応） |
| Elements (Payment Element) | ✅ | Express Checkout Elementは非対応 |
| Payment Intents API | ✅ | Direct API呼び出し |
| モバイル（iOS/Android） | ✅ | StripePaymentsUI SDK使用 |

## 実装パターン

### パターン1: Checkout Session（最もシンプル — Usacon推奨）

#### サーバーサイド（TypeScript）
```typescript
app.post('/create-checkout-session', async (req, res) => {
  const session = await stripe.checkout.sessions.create({
    line_items: [
      {
        price_data: {
          currency: 'jpy',
          product_data: { name: 'T-shirt' },
          unit_amount: 1000,
        },
        quantity: 1,
      },
    ],
    mode: 'payment',
    // ダッシュボード管理の場合は payment_method_types 不要
    // 手動指定の場合:
    // payment_method_types: ['card', 'paypay'],
    success_url: 'https://example.com/success?session_id={CHECKOUT_SESSION_ID}',
    cancel_url: 'https://example.com/cancel',
  });
  res.redirect(303, session.url);
});
```

### パターン2: Checkout Sessions API + Elements（カスタムUI）

#### サーバーサイド
```typescript
app.post('/create-checkout-session', async (req, res) => {
  const session = await stripe.checkout.sessions.create({
    line_items: [
      {
        price_data: {
          currency: 'jpy',
          product_data: { name: 'T-shirt' },
          unit_amount: 1000,
        },
        quantity: 1,
      },
    ],
    mode: 'payment',
    ui_mode: 'elements',
    return_url: 'https://example.com/return?session_id={CHECKOUT_SESSION_ID}',
  });
  res.json({ checkoutSessionClientSecret: session.client_secret });
});
```

#### クライアントサイド（React）
```tsx
import { CheckoutElementsProvider } from '@stripe/react-stripe-js/checkout';
import { PaymentElement, useCheckout } from '@stripe/react-stripe-js/checkout';

const App = () => (
  <CheckoutElementsProvider stripe={stripePromise} options={{ clientSecret }}>
    <CheckoutForm />
  </CheckoutElementsProvider>
);

const CheckoutForm = () => {
  const checkoutState = useCheckout();
  if (checkoutState.type === 'loading') return <div>Loading...</div>;

  const handleClick = () => {
    checkoutState.checkout.confirm().then((result) => {
      if (result.type === 'error') console.error(result.error);
    });
  };

  return (
    <form>
      <PaymentElement options={{ layout: 'accordion' }} />
      <button
        disabled={!checkoutState.checkout.canConfirm}
        onClick={handleClick}
      >
        支払う
      </button>
    </form>
  );
};
```

### パターン3: Payment Intents API + Elements（既存実装への追加）

#### サーバーサイド
```typescript
app.post('/create-intent', async (req, res) => {
  const intent = await stripe.paymentIntents.create({
    amount: 1000,
    currency: 'jpy',
    // ダッシュボード管理: automatic_payment_methods が有効なら不要
    // 手動指定:
    // payment_method_types: ['card', 'paypay'],
  });
  res.json({ client_secret: intent.client_secret });
});
```

#### クライアントサイド（React）
```tsx
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js';

const App = () => {
  const options = {
    mode: 'payment' as const,
    amount: 1000,
    currency: 'jpy',
    // 手動指定: paymentMethodTypes: ['card', 'paypay'],
  };
  return (
    <Elements stripe={stripePromise} options={options}>
      <CheckoutForm />
    </Elements>
  );
};

const CheckoutForm = () => {
  const stripe = useStripe();
  const elements = useElements();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;

    const { error: submitError } = await elements.submit();
    if (submitError) return;

    const res = await fetch('/create-intent', { method: 'POST' });
    const { client_secret } = await res.json();

    const { error } = await stripe.confirmPayment({
      elements,
      clientSecret: client_secret,
      confirmParams: { return_url: 'https://example.com/complete' },
    });
    if (error) console.error(error);
  };

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      <button type="submit" disabled={!stripe}>支払う</button>
    </form>
  );
};
```

### パターン4: Direct API（フロントエンドなし / サーバーサイドのみ）

```bash
# PaymentIntent作成
curl https://api.stripe.com/v1/payment_intents \
  -u "sk_test_xxx:" \
  -d "payment_method_types[]=paypay" \
  -d amount=1000 \
  -d currency=jpy

# 確認（PayPay認証ページへリダイレクト）
curl https://api.stripe.com/v1/payment_intents/pi_xxx/confirm \
  -u "sk_test_xxx:" \
  -d payment_method=pm_xxx \
  --data-urlencode "return_url=https://example.com/complete"
```

#### クライアントサイドで直接確認
```javascript
const { error } = await stripe.confirmPayment({
  clientSecret,
  confirmParams: {
    payment_method_data: { type: 'paypay' },
    return_url: `${window.location.href}`,
  },
});
```

### パターン5: モバイル（iOS - Swift）

```swift
// PaymentMethodパラメータ作成
let paypay = STPPaymentMethodPaypayParams()
let paymentMethodParams = STPPaymentMethodParams(
  paypay: paypay, billingDetails: nil, metadata: nil
)

let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
paymentIntentParams.paymentMethodParams = paymentMethodParams
paymentIntentParams.returnURL = "your-app://stripe-redirect"

// 決済確認
STPPaymentHandler.shared().confirmPayment(paymentIntentParams, with: self) {
  (status, intent, error) in
  switch status {
  case .succeeded: break // 成功
  case .canceled:  break // キャンセル
  case .failed:    break // 失敗
  @unknown default: fatalError()
  }
}
```

### パターン6: モバイル（Android - Kotlin）

```kotlin
// PaymentMethodパラメータ作成
val paypayParams = PaymentMethodCreateParams.createPaypay()
val confirmParams = ConfirmPaymentIntentParams
  .createWithPaymentMethodCreateParams(
    paymentMethodCreateParams = paypayParams,
    clientSecret = paymentIntentClientSecret,
  )

// 決済確認
paymentLauncher.confirm(confirmParams)
```

## 決済フロー（リダイレクト方式）

```
顧客 → 加盟店サイト → Stripe API (PaymentIntent作成)
  → 顧客をPayPay認証ページへリダイレクト
  → PayPayアプリ/Webで承認
  → return_url にリダイレクト（クエリパラメータ付き）
  → Webhook: payment_intent.succeeded
```

### return_url に付与されるパラメータ
| パラメータ | 説明 |
|-----------|------|
| `payment_intent` | PaymentIntentの一意識別子 |
| `payment_intent_client_secret` | client_secret |

カスタムクエリパラメータもリダイレクトで保持される。

## Webhook イベント

| イベント | 用途 |
|---------|------|
| `payment_intent.succeeded` | 決済成功 |
| `payment_intent.payment_failed` | 決済失敗 |
| `refund.updated` | 返金ステータス更新 |
| `refund.failed` | 返金失敗 |

**重要**: クライアント側コールバックだけに依存しない。Webhookで非同期に結果を確認すること。

## テスト方法

サンドボックスモードでは、テスト決済ページにリダイレクトされ「承認」「拒否」を選択できる。

```bash
# Stripe CLIでテスト
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# PaymentIntent作成テスト
stripe payment_intents create \
  --amount=1000 \
  --currency=jpy \
  -d "payment_method_types[]=paypay"
```

## エラーコード

| コード | 説明 | 対応 |
|--------|------|------|
| `payment_intent_invalid_currency` | JPY以外の通貨指定 | `currency: 'jpy'` を確認 |
| `missing_required_parameter` | 必須パラメータ不足 | エラーメッセージで確認 |
| `payment_intent_payment_attempt_failed` | 決済試行失敗 | `last_payment_error.code` を確認 |
| `payment_intent_authentication_failure` | PayPay認証失敗 | ユーザーに再試行を促す |
| `payment_intent_redirect_confirmation_without_return_url` | return_url未指定 | `return_url` を指定 |

## Usaconへの導入方針

### 既存Stripe基盤への追加が最小コスト
1. Stripeダッシュボードで PayPay を有効化
2. `automatic_payment_methods` が有効なら **コード変更不要**（Stripeが自動表示）
3. 手動指定の場合: `payment_method_types` に `'paypay'` を追加

### ⚠️ サブスクリプション非対応の影響
Usaconの月額課金にPayPayは使えない。ワンタイム決済（単発サービス購入、追加オプション等）でのみ利用可能。

### Webhookは既存のまま
`payment_intent.succeeded` 等のイベントは既存のWebhookハンドラで受信できる。PayPay固有のイベントは発生しない。

## 返金ハンドリング

```typescript
// 全額返金
const refund = await stripe.refunds.create({
  payment_intent: 'pi_xxx',
});

// 一部返金
const refund = await stripe.refunds.create({
  payment_intent: 'pi_xxx',
  amount: 500, // JPY
});
```

- PayPay返金は即時完了
- 返金失敗時: `refund.failed` Webhookで通知、金額はStripe残高に返却
- 返金期限: 購入後最大365日

## NPM パッケージ

```bash
# React + Stripe.js
npm install @stripe/react-stripe-js@^5.0.0 @stripe/stripe-js@^8.0.0

# サーバーサイド
npm install stripe
```

## 参考
- Stripe PayPay概要: https://stripe.com/jp/payment-method/paypay
- 実装ガイド: https://docs.stripe.com/payments/paypay/accept-a-payment
- Stripe決済手段設定: Stripeダッシュボード

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-07 | 初版作成 | Usacon PayPay決済導入検討。PAY.JP → Stripe PayPayに方針変更 |
