---
name: liftkit
description: "LiftKit UIフレームワーク（黄金比ベース）でのNext.js開発支援。コンポーネント作成、セットアップ、デザインシステム、ユーティリティクラス、テーマカスタマイズのガイダンスを提供。"
---

# LiftKit - Golden Ratio UI Framework for Next.js

## 概要

LiftKitは黄金比（φ = 1.618）に基づくオープンソースUIフレームワーク。Next.js専用（現時点）。
従来の絶対値ベース（px, pt）のUIシステムと異なり、相対単位（em, rem, %）と指数スケーリングを使用し、光学的対称性を自動適用する。

- **パッケージ:** `@chainlift/liftkit`
- **ライセンス:** Apache-2.0
- **GitHub:** https://github.com/Chainlift/liftkit
- **テンプレート:** https://github.com/Chainlift/liftkit-template
- **公式ドキュメント:** https://www.chainlift.io/liftkit
- **ステータス:** Extremely Early Access
- **Tailwind版（コミュニティ）:** https://github.com/jellydeck/liftkit-tailwind

## トリガー条件

- LiftKitコンポーネントの使用・実装を求められたとき
- 黄金比ベースのUIデザインが必要なとき
- Next.jsプロジェクトでLiftKitのセットアップ・設定が必要なとき
- LiftKitのテーマカスタマイズやカラー設定が必要なとき

## 核心ルール

1. **セマンティックトークンでカラー指定** - `"primary"`, `"secondary"`, `"error"` 等。ハードコードの色値は使わない
2. **スケーリングは `scaleFactor` に任せる** - 手動px指定は避ける。黄金比が自動計算する
3. **光学補正はデフォルトON維持** - 人間の目の知覚に合わせた自動調整を尊重する
4. **マテリアル活用** - `"glass"` で高級感、`"flat"` でクリーン、`"rubber"` で柔らかさ
5. **インポートパス規約** - `@/components/liftkit/<ComponentName>` または `@/registry/nextjs/components/<name>`
6. **`useTheme()` でテーマ状態にアクセス** - ThemeProviderでアプリをラップして使用
7. **変更は最小・可逆・段階的に** - ビジネスロジックは変えず、LiftKitの段階的採用を優先
8. **Context7で最新ドキュメント参照** - Library ID `/websites/chainlift_io_liftkit`

## クイックスタート

### インストール

**方法A: テンプレートから新規作成**
```bash
git clone https://github.com/Chainlift/liftkit-template.git
cd liftkit-template
npm install
```

**方法B: 既存のNext.jsプロジェクトに追加**
```bash
npm install @chainlift/liftkit --save-dev
npx liftkit init
```

### CSS読み込み

`globals.css` に追加:
```css
@import url('@/lib/css/index.css');
```

### コンポーネント追加

| 対象 | コマンド |
|------|---------|
| 全コンポーネント+CSS+型 | `npm run add all` |
| 個別コンポーネント | `npm run add <component-name>` |
| CSSと型のみ | `npm run add base` |

コンポーネント名はケバブケース（例: `npm run add text-input`, `npm run add icon-button`）。
依存コンポーネントは自動インストールされる（例: Badge → Icon も追加）。

### components.json

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app/globals.css",
    "baseColor": "neutral",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "iconLibrary": "lucide"
}
```

## 主要コンポーネント概要

**レイアウト:** Container, Grid, Column, Row, Section
**テキスト:** Heading, Text
**入力:** Button, IconButton, TextInput, Select, Switch
**表示:** Card, Badge, Icon, Image, Sticker, Snackbar
**ナビ:** Navbar, Tabs, Dropdown, MenuItem
**レイヤー:** MaterialLayer, StateLayer
**テーマ:** Theme (ThemeProvider), ThemeController

→ 全コンポーネントのProps定義・使用例: references/components-api.md

## デザインシステム概要

- **黄金比スケーリング** - φ = 1.618 ベースの指数スケール（wholestep/halfstep/quarterstep/eighthstep）
- **サイズトークン** - `3xs` ~ `4xl` の10段階（`LkSizeUnit`型）
- **タイポグラフィ** - 12のフォントクラス（display1 ~ capline）× 3ファミリー（regular/bold/mono）
- **カラー** - Material Design 3トーナルパレット。マスターシードから自動生成
- **マテリアル** - flat / glass / rubber の3種類
- **ダークモード** - OS追従 / プログラム制御 / data属性 / 部分適用
- **レスポンシブ** - 4段階ブレークポイント（デスクトップ992px+ / タブレット768px / モバイル横479px / モバイル縦479px未満）

→ 詳細: references/design-system.md

## ユーティリティクラス概要

Tailwindと同じクラス名を使用（Tailwind本体は不要）。38カテゴリ:
レイアウト、Flex、グリッド、サイズ、スペーシング、外観、タイポグラフィ、インタラクション、マテリアル等。

→ 全クラス一覧・UIパターンガイド・トラブルシューティング: references/utility-classes.md

## ベストプラクティス

1. **インポートパス:** `@/components/liftkit/<ComponentName>` または `@/registry/nextjs/components/<name>`
2. **カラーはセマンティックトークン:** `"primary"`, `"secondary"`, `"error"` 等
3. **マテリアル活用:** `"glass"` で高級感、`"flat"` でクリーン、`"rubber"` で柔らかさ
4. **光学補正はデフォルトON維持**
5. **スケーリングは `scaleFactor` に任せる:** 手動px指定は避ける
6. **`useTheme()` でテーマ状態にアクセス**
7. **Context7で最新ドキュメント参照:** Library ID `/websites/chainlift_io_liftkit`
8. **変更は最小・可逆・段階的に:** ビジネスロジックは変えず、LiftKitの段階的採用を優先

## 参考リンク

- 公式ドキュメント: https://www.chainlift.io/liftkit
- インストール: https://www.chainlift.io/liftkit/install
- コンポーネント: https://www.chainlift.io/liftkit/components
- ユーティリティクラス: https://www.chainlift.io/liftkit/utility-classes
- チュートリアル: https://www.chainlift.io/liftkit/tutorials
- 型定義: https://www.chainlift.io/liftkit/types
- GitHub: https://github.com/Chainlift/liftkit
- テンプレート: https://github.com/Chainlift/liftkit-template
- Context7 Library ID: `/websites/chainlift_io_liftkit`

## 関連スキル

- `ui-ux-pro-max` - UI/UXデザインガイド（スタイル・パレット・フォントペアリング）
- `ux-psychology` - UX心理学（43の心理学原則を活用したUI/UXデザイン）

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2025-12 (推定) | 初版作成 |
| 2026-03-04 | 関連スキル・改訂履歴セクション追加 |
| 2026-03-05 | リファクタリング: 詳細内容をreferences/に分割。SKILL.mdをエントリーポイント化 |
| 2026-03-18 | トリガーワード・トラブルシューティング・チェックリスト追加（skill-improve audit対応） |

**トリガー:** `liftkit`, `LiftKit`, `黄金比UI`, `golden ratio`, `@chainlift/liftkit`

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| LiftKitコンポーネントが表示されない | `@chainlift/liftkit` がインストールされているか確認 |
| Next.js App Routerで動作しない | `'use client'` ディレクティブの追加を確認 |
| テーマカスタマイズが反映されない | CSS変数のオーバーライド順序を確認 |

## LiftKit利用チェックリスト

- [ ] `@chainlift/liftkit` がpackage.jsonに追加されているか
- [ ] テーマ設定ファイルが正しく配置されているか
- [ ] レスポンシブ対応のブレークポイントを確認したか
