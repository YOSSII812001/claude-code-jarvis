---
name: awesome-design-md
description: "58+社の実在企業デザインシステム（DESIGN.md）を参照してUI実装。Stripe、Vercel、Apple、Notion、Linear等のカラー・タイポグラフィ・コンポーネント・レイアウト仕様を即座に適用。「〇〇風のデザインで」「〇〇っぽいUI」で発動。"
metadata:
  priority: 7
  filePattern:
    - "**/*.tsx"
    - "**/*.jsx"
    - "**/*.html"
    - "**/*.vue"
    - "**/*.svelte"
    - "**/*.css"
    - "**/DESIGN.md"
  bashPattern: []
  importPattern: []
  promptSignals:
    phrases:
      - "awesome-design-md"
      - "デザインシステム"
      - "DESIGN.md"
      - "Stripe風"
      - "Vercel風"
      - "Apple風"
      - "Notion風"
      - "Linear風"
      - "Supabase風"
      - "Figma風"
      - "Spotify風"
      - "風のデザイン"
      - "っぽいUI"
      - "風のUI"
      - "風にして"
      - "デザインを参考"
      - "〜のようなデザイン"
      - "design like"
      - "styled like"
      - "inspired by"
      - "design reference"
    allOf: []
    anyOf: []
    noneOf: []
    minScore: 6
---

# Awesome Design MD — 企業デザインシステムリファレンス

> Source: [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) (MIT License)
> 58+社の実在企業サイトから抽出された、実装可能なデザインシステム仕様集。

## 概要

各DESIGN.mdは以下の9セクションで構成:
1. **Visual Theme & Atmosphere** — ムード・マテリアル・空気感
2. **Color Palette** — セマンティックロール付きカラーパレット
3. **Typography** — フォント階層・ウェイト・行間・文字間隔
4. **Component Styling** — ボタン・カード・入力欄・バッジ等
5. **Layout & Spacing** — グリッド・基本単位・最大幅
6. **Depth & Shadows** — 影・エレベーション体系
7. **Design Guardrails** — Do's & Don'ts
8. **Responsive Breakpoints** — レスポンシブ対応
9. **Agent Prompt Guide** — AI実装向けガイド

## 利用可能な企業カタログ（55社）

| カテゴリ | 企業 |
|---------|------|
| **AI & ML** | claude, cohere, elevenlabs, minimax, mistral.ai, nvidia, ollama, opencode.ai, replicate, together.ai, x.ai |
| **開発者ツール** | cursor, expo, hashicorp, lovable, mintlify, posthog, raycast, sentry, voltagent, warp |
| **クラウド & インフラ** | clickhouse, mongodb, supabase, vercel |
| **デザイン & 生産性** | airtable, cal, figma, framer, miro, notion, sanity, superhuman, webflow, zapier |
| **Eコマース & 決済** | coinbase, kraken, revolut, stripe, wise |
| **コンシューマー** | airbnb, apple, bmw, pinterest, spacex, spotify, uber |
| **コミュニケーション** | intercom, resend |
| **クリエイティブ** | clay, runwayml |
| **企業向け** | ibm, linear.app |

## ワークフロー

### Step 1: 企業名を特定

ユーザーの要望から参照すべき企業を特定する。
- 「Stripe風のデザインで」→ stripe
- 「Notionっぽい感じ」→ notion
- 「モダンなダッシュボード」→ linear.app, vercel, posthog 等を提案
- 複数企業のミックスも可能（例: 「Vercelのタイポグラフィ + Stripeの色」）

### Step 2: DESIGN.mdを読み込む

```
~/.claude/skills/awesome-design-md/repo/design-md/{company}/DESIGN.md
```

**企業名→ディレクトリ名マッピング:**
- Linear → `linear.app`
- Mistral → `mistral.ai`
- Together AI → `together.ai`
- OpenCode → `opencode.ai`
- xAI / Grok → `x.ai`
- Runway → `runwayml`
- その他 → 小文字変換（Apple → `apple`, Stripe → `stripe`）

### Step 3: デザイントークンを抽出・適用

DESIGN.mdから以下を抽出してコードに反映:

1. **カラー変数**: CSS custom properties or Tailwind config として定義
2. **タイポグラフィ**: font-family, font-weight, line-height, letter-spacing
3. **スペーシング**: base unit, spacing scale
4. **シャドウ**: box-shadow値をそのまま適用
5. **border-radius**: コンポーネント別の角丸値
6. **ブレークポイント**: レスポンシブ設定

### Step 4: コンポーネント実装

DESIGN.mdのComponent Stylingセクションに従い:
- ボタン（Primary / Secondary / Ghost）
- カード（背景色、ボーダー、影）
- 入力欄（ボーダー、フォーカスリング）
- ナビゲーション
- バッジ / タグ

## 既存スキルとの連携

| スキル | 連携方法 |
|--------|---------|
| `awesome-design-md-jp`（日本語版） | 日本語UIの場合はJP版を優先。グローバル企業風カラー + JP版タイポグラフィの併用も可 |
| `frontend-skill` | DESIGN.mdのトークンをVisual Thesisに組み込む |
| `ui-ux-pro-max` | カラーパレット・タイポグラフィをDESIGN.mdから上書き |
| `ux-psychology` | UX原則はux-psychology、ビジュアル仕様はDESIGN.mdから |
| `liftkit` | LiftKitテーマのカスタムカラーにDESIGN.mdの値を適用 |

## ガイドライン

- **忠実度**: DESIGN.mdの色コード・フォントサイズ・影の値はそのまま使用する（独自解釈しない）
- **不足時**: DESIGN.mdにない要素は、同じデザイン言語の延長で補完する
- **ミックス**: 複数企業のDESIGN.mdを組み合わせる場合、カラーパレットは1社に統一し、タイポグラフィやレイアウトを別の1社から借用するのが安全
- **更新**: `git -C ~/.claude/skills/awesome-design-md/repo pull` で最新版を取得可能

## 使用例

```
ユーザー: 「Stripe風の料金プランページを作って」
→ stripe/DESIGN.md を読み込み
→ #533afd (Stripe Purple), sohne-var font, 4-8px radius を適用
→ カード + バッジ + ボタンのコンポーネントをStripe仕様で実装

ユーザー: 「VercelみたいなミニマルなLPがほしい」
→ vercel/DESIGN.md を読み込み
→ Geist font, shadow-as-border, aggressive letter-spacing を適用
→ frontend-skill と連携してLP構成を決定
```
