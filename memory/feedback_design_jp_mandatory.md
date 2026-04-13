---
name: Usacon日本語UIデザイン基準の必須適用
description: usaconプロジェクトのフロントエンドUI変更時にawesome-design-md-jpスキルの参照を必須とするルール
type: feedback
originSessionId: 7af82c32-6ed2-4feb-953c-ca987b230487
---
ウサコンのフロントエンドUI変更を含む全Issueで `awesome-design-md-jp` スキルを参照し、ウサコン標準デザインに準拠すること。

**Why:** Issue #1764でSmartHR/freee/Sansan/サイボウズ/LINEの5社デザインシステムを基にUI刷新を実施。この基準を全UI変更に一貫して適用しないと、新規UIがデザイン基準から逸脱し、品質のバラツキが生じる。

**How to apply:**
- フロントエンドUI変更（.tsx/.css/テーマファイル）を含むIssue実装時に自動的に適用
- usacon SKILL.md 核心ルール#8 + references/design-standard-jp.md に詳細記載
- issue-flow/autopilot-batch等の自動パイプラインでもサブエージェントが従う
- 特に: textTransform: 'uppercase' 禁止、テーマトークン使用必須、両テーマ確認必須
