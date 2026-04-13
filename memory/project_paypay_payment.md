---
name: PayPay決済導入方針（Stripe経由）
description: Usacon PayPay決済はStripe PayPayで実装する方針。PAY.JP導入は見送り。PayPay Developer アカウント情報あり。
type: project
---

Usaconへの PayPay 決済導入は **Stripe PayPay** で実装する（PAY.JP導入は見送り）。

**Why:** Usaconは既にStripe基盤。PAY.JPは新プロバイダー統合が必要で、v2はサブスクリプション未対応。Stripe PayPayならダッシュボード有効化 + `payment_method_types` 追加で済む。

**How to apply:**
- `stripe-cli` スキル → `stripe-paypay` サブスキルを参照
- `payjp-cli` スキルは参考資料として残存
- Stripe PayPayはサブスクリプション非対応 → ワンタイム決済のみ
- `automatic_payment_methods` が有効ならコード変更不要

## 外部アカウント
- **PayPay Developer Portal**: https://developer.paypay.ne.jp/
- **アカウント**: robbits.develop@gmail.com
- **パスワード**: パスワードマネージャーで管理（平文保存しない）

## スキル構成
- `~/.claude/skills/stripe-cli/SKILL.md` — メインスキル（PayPayセクション追加済み）
- `~/.claude/skills/stripe-paypay/SKILL.md` — PayPay決済サブスキル（6実装パターン・制約・テスト）
- `~/.claude/skills/payjp-cli/SKILL.md` — PAY.JP CLI参考資料（将来削除可）
