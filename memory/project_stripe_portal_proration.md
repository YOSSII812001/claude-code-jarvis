---
name: Stripe Portal Configuration & Proration の教訓
description: Customer Portal の proration_behavior デフォルト値の罠、next_reset_at 計算の注意点、セットアップスクリプト実行手順
type: project
---

Stripe Customer Portal Configuration の `proration_behavior` はデフォルト `none`（日割りなし）。Subscription API のデフォルト `create_prorations` とは異なるため、明示指定しないとプラン変更時の差額が請求されない（Issue #1434、最大¥130,000/月の請求漏れ）。

**Why:** 同じStripeでもAPIレイヤーごとにデフォルト値が異なることを把握していなかった。Portal経由のプラン変更で日割りが効かず売上損失。

**How to apply:**
- Portal Configuration 変更時は `proration_behavior: 'create_prorations'` を必ず明示指定
- コードデプロイだけではStripe側は更新されない → `api/scripts/setup-stripe-portal-configs.js` をテスト環境+本番環境で再実行が必要
- 実行手順: `.env.preview` (テスト) / `vercel env pull` (本番) で環境変数を読み込んでから実行
- 本番キー使用後は `.env.production.local` を必ず削除

月額プランの `next_reset_at` は Stripe の `period.end` をそのまま使用する（Issue #1435）。`computeNextResetAtFromAnchor` に渡すと1か月ズレる。Stripe が正確な値を返す場合、クライアント側で再計算しないこと。

詳細: `~/.claude/skills/usacon/references/stripe-portal-proration.md`
