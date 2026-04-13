# Usacon Stripe料金設計ガイド

## 概要

Usaconの決済はStripe Subscriptionを使用。月額/年額の2つの支払い間隔に対応。

## 料金プラン構造

### プラン一覧

| プラン | 月額 | 年額（1ヶ月分お得） | クレジット |
|--------|------|-------------------|----------|
| Free | ¥0 | - | 10/月 |
| Standard | ¥70,000 | ¥770,000 | 100/月 |
| Professional | ¥200,000 | ¥2,200,000 | 500/月 |

### 年額の割引計算

```
Standard年額:      ¥70,000 × 11ヶ月 = ¥770,000（1ヶ月分お得）
Professional年額: ¥200,000 × 11ヶ月 = ¥2,200,000（1ヶ月分お得）
```

## Stripe構造：商品と価格

### 設計思想

```
┌─────────────────────────────────────────────────────────┐
│ Stripe の構造                                           │
├─────────────────────────────────────────────────────────┤
│  商品（Product）= 論理的なグループ（管理・表示用）        │
│  価格（Price）  = 実際の課金に使用するID                 │
│                                                         │
│  コードは price_ ID のみを使用するため、                 │
│  商品構造は「4商品・4価格」でも「2商品・4価格」でも動作   │
└─────────────────────────────────────────────────────────┘
```

### 現在の構造

> **最新のPrice IDは「Price ID一覧（最新）」セクションを参照。** 以下の旧Price IDは無効化済み。

#### 旧構成（廃止済み — 価格改定前）

| 商品名 | Product ID | Price ID | 旧金額 | interval | 状態 |
|--------|-----------|----------|--------|----------|------|
| Standard Plan | `prod_TokaHcnA2MPYkS` | `price_1Sr75hQWzpid7on2Bo3pNCpU` | ¥50,000 | month | **無効** |
| Standard Plan（年払い） | `prod_TuMKSE5dU8tSG1` | `price_1SwXcIQWzpid7on2duYcAIBx` | ¥550,000 | year | **無効** |
| Professional Plan | `prod_Toka86tJAbuZKY` | `price_1Sr75FQWzpid7on2it48DKHI` | ¥150,000 | month | **無効** |
| Professional Plan（年払い） | `prod_TuMMOLQzBLqi7X` | `price_1SwXdyQWzpid7on26SGUit4M` | ¥1,650,000 | year | **無効** |

## 環境変数

### 必要な環境変数（8個の価格ID）

```env
# バックエンド用（STRIPE_プレフィックス）
STRIPE_PRICE_STANDARD_ID=price_xxx        # Standard月額
STRIPE_PRICE_PROFESSIONAL_ID=price_xxx    # Professional月額
STRIPE_PRICE_STANDARD_YEAR_ID=price_xxx   # Standard年額
STRIPE_PRICE_PROFESSIONAL_YEAR_ID=price_xxx # Professional年額

# フロントエンド用（VITE_プレフィックス）
VITE_STRIPE_PRICE_STANDARD_ID=price_xxx
VITE_STRIPE_PRICE_PROFESSIONAL_ID=price_xxx
VITE_STRIPE_PRICE_STANDARD_YEAR_ID=price_xxx
VITE_STRIPE_PRICE_PROFESSIONAL_YEAR_ID=price_xxx
```

### Vercel環境別設定

| 環境 | APIキー | 価格ID |
|------|---------|--------|
| Production | `sk_live_...` | 本番用 price_ |
| Preview | `sk_test_...` | テスト用 price_ |
| Development | `sk_test_...` | テスト用 price_ |

## コードベースの価格ID管理

### フロントエンド：PlanBox.tsx

```typescript
// frontend/src/components/pricing/PlanBox.tsx
const priceIdByPlanId: Record<string, { monthly?: string; annual?: string }> = {
    standard: {
        monthly: import.meta.env.VITE_STRIPE_PRICE_STANDARD_ID,
        annual: import.meta.env.VITE_STRIPE_PRICE_STANDARD_YEAR_ID,
    },
    professional: {
        monthly: import.meta.env.VITE_STRIPE_PRICE_PROFESSIONAL_ID,
        annual: import.meta.env.VITE_STRIPE_PRICE_PROFESSIONAL_YEAR_ID,
    },
};
```

### バックエンド：payment.js

```javascript
// api/_lib/routes/payment.js
const PRICE_TO_PLAN_CODE = (() => {
    const map = {};
    const entries = [
        [process.env.STRIPE_PRICE_STANDARD_ID, 'standard'],
        [process.env.STRIPE_PRICE_PROFESSIONAL_ID, 'professional'],
        [process.env.STRIPE_PRICE_STANDARD_YEAR_ID, 'standard'],
        [process.env.STRIPE_PRICE_PROFESSIONAL_YEAR_ID, 'professional'],
    ];
    entries.forEach(([priceId, planCode]) => {
        if (priceId) map[priceId] = planCode;
    });
    return map;
})();
```

### プラン定義：constants/plans.ts

```typescript
// frontend/src/constants/plans.ts
{
    id: 'standard',
    name: 'スタンダード',
    price: { monthly: '¥70,000', annual: '¥770,000' },
    period: { monthly: '/月（税込み）', annual: '/年（税込み）' },
    credit: 100,
    features: [...],
},
{
    id: 'professional',
    name: 'プロフェッショナル',
    price: { monthly: '¥200,000', annual: '¥2,200,000' },
    period: { monthly: '/月（税込み）', annual: '/年（税込み）' },
    credit: 500,
    features: [...],
}
```

## 購読フロー

```
ユーザー: 「購読」ボタンクリック
         ↓
PlanBox.tsx: handleSubscribeAction(planId, billingCycle)
         ↓
subscribe(planId, userId, billingCycle)
  ├─ priceIdByPlanId[planId][billingCycle] で価格ID取得
  └─ POST /api/payment/create-checkout-session
         ↓
バックエンド:
  ├─ priceId → planCode 変換（PRICE_TO_PLAN_CODE）
  ├─ Stripe Customer 作成/取得
  └─ Checkout Session 作成
         ↓
stripe.checkout.sessions.create({
    line_items: [{ price: priceId, quantity: 1 }],
    mode: 'subscription',
    metadata: { userId, orgId, planCode, priceId }
})
         ↓
ユーザー: Stripe Checkout画面で決済
         ↓
Webhook: checkout.session.completed
  ├─ billing.customers 更新
  ├─ billing.subscriptions 作成
  │   └─ price_interval = 'month' or 'year'
  └─ billing.credit_balances にクレジット付与
```

## Supabaseでの管理（billing スキーマ）

### ER図

```
┌─────────────────────┐
│  billing.customers  │
├─────────────────────┤
│ id (PK)             │
│ org_id (FK)         │───────────────────┐
│ stripe_customer_id  │                   │
│ email               │                   │
│ contract_start_date │                   │
└─────────────────────┘                   │
          │                               │
          │ 1:1                           │
          ▼                               │
┌──────────────────────────┐              │
│  billing.subscriptions   │              │
├──────────────────────────┤              │
│ id (PK)                  │              │
│ customer_id (FK)         │◀─────────────┘
│ plan_code (enum)         │  'free'|'standard'|'professional'
│ price_interval           │  'month'|'year' ← Stripeから取得
│ stripe_subscription_id   │
│ status                   │  'active'|'canceled'|...
│ monthly_credit_quota     │
│ next_reset_at            │
└──────────────────────────┘
          │
          │ 1:1
          ▼
┌──────────────────────────┐
│  billing.credit_balances │
├──────────────────────────┤
│ subscription_id (PK/FK)  │
│ credits_remaining        │
│ updated_at               │
└──────────────────────────┘
          │
          │ 1:N
          ▼
┌──────────────────────────┐
│  billing.credit_ledger   │  履歴・監査ログ
├──────────────────────────┤
│ id (PK)                  │
│ subscription_id (FK)     │
│ change_amount            │  +100, -1 など
│ reason                   │  'monthly_reset', 'usage', ...
│ metadata (jsonb)         │
│ occurred_at              │
└──────────────────────────┘

┌──────────────────────────┐
│  billing.webhook_events  │  Stripe Webhook履歴
├──────────────────────────┤
│ id (PK)                  │
│ event_id                 │  Stripe evt_xxx
│ event_type               │  'checkout.session.completed'
│ payload (jsonb)          │
│ processed_at             │
│ created_at               │
└──────────────────────────┘
```

### 1. billing.customers（顧客）

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `id` | uuid | NO | gen_random_uuid() | PK |
| `org_id` | uuid | YES | - | FK → organizations |
| `stripe_customer_id` | text | YES | - | Stripe cus_xxx |
| `email` | text | YES | - | 顧客メール |
| `contract_start_date` | date | NO | CURRENT_DATE | 契約開始日 |
| `created_at` | timestamptz | YES | now() | 作成日時 |
| `updated_at` | timestamptz | YES | now() | 更新日時 |

### 2. billing.subscriptions（サブスクリプション）

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `id` | uuid | NO | gen_random_uuid() | PK |
| `customer_id` | uuid | YES | - | FK → customers |
| `plan_code` | enum | NO | 'free' | 'free', 'standard', 'professional' |
| `price_interval` | text | YES | - | **'month' or 'year'** ← 重要 |
| `stripe_subscription_id` | text | YES | - | Stripe sub_xxx |
| `status` | text | YES | 'active' | 'active', 'canceled', 'past_due', ... |
| `monthly_credit_quota` | integer | YES | - | 月間クレジット上限 |
| `next_reset_at` | timestamptz | YES | - | クレジットリセット日時 |
| `created_at` | timestamptz | YES | now() | 作成日時 |
| `updated_at` | timestamptz | YES | now() | 更新日時 |

**重要:** `price_interval` で月額/年額を区別。Stripe Webhookから取得。

### 3. billing.credit_balances（クレジット残高）

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `subscription_id` | uuid | NO | - | PK/FK → subscriptions |
| `credits_remaining` | integer | NO | 0 | 残りクレジット |
| `updated_at` | timestamptz | YES | now() | 更新日時 |

### 4. billing.credit_ledger（クレジット履歴）

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `id` | uuid | NO | gen_random_uuid() | PK |
| `subscription_id` | uuid | YES | - | FK → subscriptions |
| `change_amount` | integer | NO | - | 変動量（+100, -1） |
| `reason` | text | NO | - | 理由（'monthly_reset', 'usage'） |
| `metadata` | jsonb | YES | '{}' | 追加情報 |
| `occurred_at` | timestamptz | YES | now() | 発生日時 |

### 5. billing.webhook_events（Webhook履歴）

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `id` | uuid | NO | gen_random_uuid() | PK |
| `event_id` | text | NO | - | Stripe evt_xxx |
| `event_type` | text | NO | - | イベント種別 |
| `payload` | jsonb | YES | - | 全ペイロード |
| `processed_at` | timestamptz | NO | now() | 処理日時 |
| `created_at` | timestamptz | NO | now() | 作成日時 |

### price_interval の取得

Webhookで Stripe Subscription から取得：

```javascript
const subscription = await stripe.subscriptions.retrieve(subscriptionId);
const priceInterval = subscription.items.data[0].price.recurring.interval;
// → 'month' または 'year'
```

## 新しい価格を追加する手順

### 1. Stripeで価格を作成

```bash
# 既存商品に新しい価格を追加
stripe prices create \
  --product=prod_xxx \
  --unit-amount=550000 \
  --currency=jpy \
  --recurring-interval=year
```

### 2. 環境変数を追加

```bash
# Vercel Preview環境
printf 'price_xxx' | npx vercel env add STRIPE_PRICE_STANDARD_YEAR_ID preview
printf 'price_xxx' | npx vercel env add VITE_STRIPE_PRICE_STANDARD_YEAR_ID preview

# Vercel Production環境
printf 'price_xxx' | npx vercel env add STRIPE_PRICE_STANDARD_YEAR_ID production
printf 'price_xxx' | npx vercel env add VITE_STRIPE_PRICE_STANDARD_YEAR_ID production
```

### 3. コードを更新（必要に応じて）

`PRICE_TO_PLAN_CODE` と `priceIdByPlanId` に新しいエントリを追加。

### 4. デプロイ

```bash
npx vercel --yes  # Preview
npx vercel --prod --yes  # Production
```

## 注意点・ベストプラクティス

### 推奨

1. **価格IDベースで管理** - 商品構造に依存しない設計
2. **環境変数で価格ID管理** - 環境ごとに切り替え可能
3. **Webhookで`price_interval`取得** - Stripeから正確な情報を取得
4. **テスト環境で十分にテスト** - `sk_test_` で動作確認後に本番へ

### 避けるべき

1. **価格IDのハードコード** - 環境変数を使用すること
2. **商品IDへの依存** - `prod_` ではなく `price_` を使用
3. **Webhookなしでのステータス管理** - 必ずWebhookで同期

## 関連ファイル

```
フロントエンド:
├─ frontend/src/pages/account/Pricing.tsx      # 料金ページ
├─ frontend/src/components/pricing/PlanBox.tsx # プランボックス
├─ frontend/src/constants/plans.ts             # プラン定義
└─ frontend/src/actions/price.ts               # 購読アクション

バックエンド:
├─ api/_lib/routes/payment.js                  # Checkout Session作成
├─ api/_lib/routes/webhook.js                  # Webhook処理
└─ scripts/setup-stripe-portal-configs.js      # Customer Portal設定スクリプト

環境変数:
├─ .env.example                                # ローカル開発用テンプレート
└─ .env.production.example                     # 本番用テンプレート
```

---

## Stripe 設定詳細

### テスト/本番モード切り替え

Stripeはテストモードと本番モードで完全に別のデータベースを持つ。環境変数で切り替え。

| 環境 | APIキー接頭辞 | 用途 |
|------|--------------|------|
| テスト | `sk_test_` | ローカル開発・テスト |
| 本番 | `sk_live_` | 本番デプロイ |

### Price ID一覧（最新）

| プラン | 価格 | テスト用（ウサコンサンドボックス） | 本番用 |
|--------|------|-----------------------------------|--------|
| Standard Monthly | ¥70,000/月 | `price_1SzoxaQWzpid7on2hzaXERND` | `price_1SzsUOHbOWA7CJ3Rn4G8bckK` |
| Standard Annual | ¥770,000/年 | `price_1SzoxcQWzpid7on2yMWNtTx8` | `price_1SzsUUHbOWA7CJ3RBQ5dXCk7` |
| Professional Monthly | ¥200,000/月 | `price_1SzoxeQWzpid7on2zjUKO4Zm` | `price_1SzsUZHbOWA7CJ3Rar3uFdbW` |
| Professional Annual | ¥2,200,000/年 | `price_1SzoxfQWzpid7on2kkXZr9lz` | `price_1SzsUfHbOWA7CJ3RqAyTKXp7` |

> **旧Price ID（無効化済み）:**
> - Standard ¥50,000/月: `price_1Sr75hQWzpid7on2Bo3pNCpU`（テスト）/ `price_1Sr8WPHbOWA7CJ3RH18iZutG`（本番）
> - Professional ¥150,000/月: `price_1Sr75FQWzpid7on2it48DKHI`（テスト）/ `price_1Sr8W9HbOWA7CJ3R99xf9byI`（本番）

### 環境変数設定

**ローカル開発（`.env`）:**
```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PRICE_STANDARD_ID=price_1SzoxaQWzpid7on2hzaXERND
STRIPE_PRICE_PROFESSIONAL_ID=price_1SzoxeQWzpid7on2zjUKO4Zm
STRIPE_PRICE_STANDARD_YEAR_ID=price_1SzoxcQWzpid7on2yMWNtTx8
STRIPE_PRICE_PROFESSIONAL_YEAR_ID=price_1SzoxfQWzpid7on2kkXZr9lz
VITE_STRIPE_PRICE_STANDARD_ID=price_1SzoxaQWzpid7on2hzaXERND
VITE_STRIPE_PRICE_PROFESSIONAL_ID=price_1SzoxeQWzpid7on2zjUKO4Zm
VITE_STRIPE_PRICE_STANDARD_YEAR_ID=price_1SzoxcQWzpid7on2yMWNtTx8
VITE_STRIPE_PRICE_PROFESSIONAL_YEAR_ID=price_1SzoxfQWzpid7on2kkXZr9lz
CLIENT_URL=http://localhost:5173
```

**本番環境（Vercel）:**
```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_T4vWPk0lsRJYRysjmPdoD2QCHwZ5TiSE
STRIPE_PRICE_STANDARD_ID=price_1SzsUOHbOWA7CJ3Rn4G8bckK
STRIPE_PRICE_PROFESSIONAL_ID=price_1SzsUZHbOWA7CJ3Rar3uFdbW
STRIPE_PRICE_STANDARD_YEAR_ID=price_1SzsUUHbOWA7CJ3RBQ5dXCk7
STRIPE_PRICE_PROFESSIONAL_YEAR_ID=price_1SzsUfHbOWA7CJ3RqAyTKXp7
CLIENT_URL=https://usacon-ai.com
```

### Webhook設定

| 環境 | エンドポイント | 署名シークレット | Webhook ID |
|------|---------------|-----------------|------------|
| ローカル | `localhost:5000/api/payment/webhook` | `stripe listen`で自動生成 | - |
| Preview | `https://preview.usacon-ai.com/api/payment/webhook` | `whsec_WO9V5I5gYlsWYaRkWtxHAmCxl9B7qMnj` | `we_1SwgBCQWzpid7on2CwQTxf7r` |
| 本番 | `https://usacon-ai.com/api/payment/webhook` | `whsec_T4vWPk0lsRJYRysjmPdoD2QCHwZ5TiSE` | - |

**Stripeアカウント情報:**
- **テスト環境**: ウサコン サンドボックス（`acct_1Sr6uLQWzpid7on2`）
- **本番環境**: 本番アカウント（`sk_live_`で始まるキー使用）

**本番Webhookで受信するイベント（6件）:**
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`

### ローカル決済テスト手順

```bash
# ターミナル1: Webhook転送開始
stripe listen --forward-to localhost:5000/api/payment/webhook

# ターミナル2: バックエンド起動
npm run dev:backend

# ターミナル3: フロントエンド起動
npm run dev:frontend

# ブラウザでhttp://localhost:5173にアクセスし、Pricingページで決済テスト
# テストカード: 4242 4242 4242 4242
```

### Customer Portal設定

| 項目 | 値 |
|------|-----|
| リダイレクトURL | `https://usacon-ai.com/billing` |
| ポータル設定ID | `bpc_1Su1ZMHbOWA7CJ3RDgMRVK7v` |
| 設定スクリプト | `scripts/setup-stripe-portal-configs.js` |

#### ⚠️ proration_behavior（日割り計算）の注意

Customer Portal Configuration の `proration_behavior` は **APIレイヤーによってデフォルト値が異なる**。
Issue #1434 で、Portal Configuration のデフォルト `none` により最大¥130,000/月の請求漏れが発生（Standard→Professional月額差額）。

| APIレイヤー | パラメータ | デフォルト値 | 意味 |
|------------|-----------|-------------|------|
| Subscription API (`stripe.subscriptions.update`) | `proration_behavior` | `create_prorations` | 日割り計算あり（安全） |
| Customer Portal Configuration | `proration_behavior` | `none` | **日割り計算なし（危険）** |
| Checkout Session | - | 新規作成のため該当なし | - |

**推奨設定:**
- Customer Portal Configuration では `proration_behavior: 'create_prorations'` を **必ず明示的に設定** する
- 年額プランでアップグレード時の日割り金額が大きい場合は `always_invoice`（即時請求）も検討（`create_prorations` は日割り項目を作成するが即時Invoiceは発行しない。`always_invoice` は即時Invoice発行+請求）
- `scripts/setup-stripe-portal-configs.js` で設定を管理（手動Dashboard操作に依存しない）

```javascript
// setup-stripe-portal-configs.js の重要パラメータ
const config = await stripe.billingPortal.configurations.create({
  business_profile: { headline: 'サブスクリプション管理' },
  features: {
    subscription_update: {
      enabled: true,
      proration_behavior: 'create_prorations', // ← 必ず明示的に設定
      default_allowed_updates: ['price'],
      products: [/* ... */],
    },
    // ...
  },
});
```

---

## Vercel 環境変数管理

### 環境分離機能

Vercelでは環境変数を**環境ごとに異なる値**で設定可能。テスト用と本番用を安全に共存させられる。

| 環境 | 用途 | Stripe設定 |
|------|------|------------|
| **Production** | 本番 `usacon-ai.com` | 本番用キー (sk_live_...) |
| **Preview** | PRプレビュー | テスト用キー (sk_test_...) |
| **Development** | ローカル連携 | テスト用キー (sk_test_...) |

### 推奨構成

```
# 各環境変数の設定値（環境別）

STRIPE_SECRET_KEY:
  Production: sk_live_xxxxxxx（本番キー）
  Preview/Development: sk_test_xxxxxxx（テストキー）

STRIPE_PRICE_STANDARD_ID:
  Production: price_1SzsUOHbOWA7CJ3Rn4G8bckK
  Preview/Development: price_1SzoxaQWzpid7on2hzaXERND

STRIPE_PRICE_PROFESSIONAL_ID:
  Production: price_1SzsUZHbOWA7CJ3Rar3uFdbW
  Preview/Development: price_1SzoxeQWzpid7on2zjUKO4Zm

STRIPE_PRICE_STANDARD_YEAR_ID:
  Production: price_1SzsUUHbOWA7CJ3RBQ5dXCk7
  Preview/Development: price_1SzoxcQWzpid7on2yMWNtTx8

STRIPE_PRICE_PROFESSIONAL_YEAR_ID:
  Production: price_1SzsUfHbOWA7CJ3RqAyTKXp7
  Preview/Development: price_1SzoxfQWzpid7on2kkXZr9lz

STRIPE_WEBHOOK_SECRET:
  Production: whsec_T4vWPk0lsRJYRysjmPdoD2QCHwZ5TiSE
  Preview: whsec_WO9V5I5gYlsWYaRkWtxHAmCxl9B7qMnj
  Development: （設定不要、ローカルはstripe listenで生成）

CLIENT_URL:
  Production: https://usacon-ai.com
  Preview: （動的プレビューURL、未設定でOK）
  Development: http://localhost:5173
```

### 環境変数の設定手順

1. Vercelダッシュボード → Project Settings → Environment Variables
2. 環境変数の「Edit」をクリック
3. 「Environments」で適用環境を選択:
   - Production（本番値を設定）
   - Preview（テスト値を設定）
   - Development（テスト値を設定）
4. 同じ変数名で**複数の値を環境別に設定**可能

### 環境分離のメリット

1. **安全なテスト**: PRプレビューでStripe決済をテストカードで検証可能
2. **本番への影響なし**: Preview環境での操作が本番Stripeに影響しない
3. **開発効率**: 本番前にフル機能テストができる
4. **ロールバック容易**: テスト環境で問題発見→本番デプロイ前に修正

### 環境変数一覧（本番用）

| 変数名 | 本番値 |
|--------|--------|
| `CLIENT_URL` | `https://usacon-ai.com` |
| `STRIPE_SECRET_KEY` | `sk_live_...`（Stripeダッシュボードから取得） |
| `STRIPE_WEBHOOK_SECRET` | `whsec_T4vWPk0lsRJYRysjmPdoD2QCHwZ5TiSE` |
| `STRIPE_PRICE_STANDARD_ID` | `price_1SzsUOHbOWA7CJ3Rn4G8bckK` |
| `STRIPE_PRICE_PROFESSIONAL_ID` | `price_1SzsUZHbOWA7CJ3Rar3uFdbW` |
| `STRIPE_PRICE_STANDARD_YEAR_ID` | `price_1SzsUUHbOWA7CJ3RBQ5dXCk7` |
| `STRIPE_PRICE_PROFESSIONAL_YEAR_ID` | `price_1SzsUfHbOWA7CJ3RqAyTKXp7` |
| `VITE_STRIPE_PRICE_STANDARD_ID` | `price_1SzsUOHbOWA7CJ3Rn4G8bckK` |
| `VITE_STRIPE_PRICE_PROFESSIONAL_ID` | `price_1SzsUZHbOWA7CJ3Rar3uFdbW` |
| `VITE_STRIPE_PRICE_STANDARD_YEAR_ID` | `price_1SzsUUHbOWA7CJ3RBQ5dXCk7` |
| `VITE_STRIPE_PRICE_PROFESSIONAL_YEAR_ID` | `price_1SzsUfHbOWA7CJ3RqAyTKXp7` |

## 関連スキル

- [../SKILL.md](../SKILL.md) - Usaconプロジェクト全体のガイド
- `stripe-cli` - Stripe CLI操作（汎用）
- `supabase-cli` - Supabase操作
