# DESIGN.md — WIRED.jp

> WIRED Japan（https://wired.jp/）のデザイン仕様書。
> Condé Nast Japan の styled-components ベースのプラットフォーム。
> Puppeteer による computed style 実測値（2026-04-06 取得）に基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: エディトリアル・メディア。テクノロジーとカルチャーの先端を伝える知的で洗練されたデザイン
- **密度**: ゆったりとした大きなヒーロー画像・見出し。余白を大胆に使うマガジンレイアウト
- **キーワード**: エディトリアル、モノトーン、タイポグラフィ主導、知的、ミニマル
- **特徴**: テキスト色に純粋な `#000` を使い、白黒のコントラストが強い。ブランド専用モノスペースフォント `WiredMono` をナビやラベルに使用。記事本文にはグローバルに `palt` を適用

---

## 2. Color Palette & Roles

### Primary

- **Black** (`#000`): メインのテキスト色、ブランドカラー
- **White** (`#fff`): 背景、反転テキスト

### Neutral

- **Near Black** (`#1a1a1a`): 記事本文テキスト、セカンダリリンク
- **Dark Gray** (`#333`): 説明テキスト
- **Medium Gray** (`#757575`): メタ情報、カテゴリラベル、フッター
- **Light Gray** (`#999`): 無効状態、補助テキスト
- **Very Light Gray** (`#e5e5e5`): ナビ内テキスト

### Surface & Borders

- **Background** (`#fff`): ページ背景
- **Header Background** (`#000`): メインナビゲーション背景（黒）
- **CTA Background** (`#000`): ボタン・リンクの背景

### Consent Overlay（Fides）

- **Overlay Primary** (`#2b2e35`): 同意バナーのプライマリ色
- **Overlay Background** (`#f7fafc`): 同意バナー背景
- **Overlay Font** (`#4a5568`): 同意バナーテキスト

---

## 3. Typography Rules

### 3.1 和文フォント

- **ゴシック体**: 游ゴシック体 / 游ゴシック Medium（Windows）、ヒラギノ角ゴ ProN / Pro（macOS）、MS ゴシック（レガシー）
- 特徴: Helvetica Neue を最優先し、和文は游ゴシックとヒラギノの二系統でフォールバック

### 3.2 欧文フォント

- **サンセリフ**: HelveticaNeue / Helvetica Neue / Helvetica / Arial — 本文・見出し用
- **ブランドモノスペース**: `WiredMono` — ナビゲーション、カテゴリラベル、セクション見出し専用の WIRED ブランドフォント
- **UI用**: Inter — 同意バナー等のオーバーレイUI

### 3.3 font-family 指定

```css
/* 本文・見出し */
font-family: HelveticaNeue, "Helvetica Neue", Helvetica, Arial,
  游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium",
  游ゴシック, "Yu Gothic", "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN",
  "ヒラギノ角ゴ Pro W3", "Hiragino Kaku Gothic Pro", "MS ゴシック", "MS Gothic",
  sans-serif;

/* ナビ・ラベル（WIRED ブランドフォント） */
font-family: WiredMono, helvetica, sans-serif;

/* 同意バナー等のUI */
font-family: Inter, sans-serif;
```

**フォールバックの考え方**:
- 欧文（Helvetica Neue 系）を最優先。WIRED は欧文主体のブランドなので欧文の表示品質を重視
- 和文は游ゴシック体 → YuGothic → 游ゴシック Medium の順（Windows の細字対策で Medium を明示）
- macOS は ヒラギノ角ゴ ProN → Pro の順
- レガシー Windows 向けに MS ゴシックまで指定
- `WiredMono` はブランド専用のカスタムフォント。ナビとラベルのみに使用

### 3.4 文字サイズ・ウェイト階層

> computed style 実測値

**記事ページ**

| Role | Font Stack | Size | Weight | Line Height | Letter Spacing | palt | 備考 |
|------|-----------|------|--------|-------------|----------------|------|------|
| Article Title (h1) | 本文用 | 32px | 700 | 52px (×1.625) | normal | あり | 記事タイトル |
| Section Heading (h2) | 本文用 | 18px | 700 | 28px (×1.556) | normal | あり | 記事内セクション見出し |
| Body (p) | 本文用 | 16px | 400 | 28px (×1.75) | normal | あり | 記事本文 |
| Author Link | WiredMono | 11px | 400 | 13px (×1.18) | normal | なし | 著者名 |
| Category Label | WiredMono | 11px | 400 | 13px (×1.18) | 0.92px (0.083em) | なし | カテゴリラベル |
| SZ Membership Badge | WiredMono | 11px | 400 | 13px (×1.18) | 1.1px (0.1em) | なし | 会員バッジ |
| Menu Button | 本文用 | 12px | 700 | 16px (×1.333) | normal | あり | ヘッダーメニュー |

**トップページ**

| Role | Font Stack | Size | Weight | Line Height | Letter Spacing | palt | 備考 |
|------|-----------|------|--------|-------------|----------------|------|------|
| Hero Title (h3) | 本文用 | 32px | 700 | 52px (×1.625) | normal | あり | ヒーロー記事見出し |
| Card Title (h3) | 本文用 | 20px | 700 | 32px (×1.6) | normal | あり | カード記事見出し |
| Section Label (h2) | WiredMono | 12px | 400 | 15.96px (×1.33) | 0.564px (0.047em) | なし | "Trending Stories" 等 |
| Section Heading (h2) | WiredMono | 18px | 400 | 28px (×1.556) | 0.564px (0.031em) | なし | "Most Recent" 等 |
| CTA Link | 本文用 | 12px | 700 | 16px (×1.333) | normal | あり | 「詳細はこちら」白抜き |
| Nav Link | WiredMono | 11px | 400 | 13px (×1.18) | 0.92px (0.083em) | なし | ナビカテゴリ |
| Footer Text | 本文用 | 11px | 400 | 16px (×1.455) | normal | あり | コピーライト等 |
| Footer Meta | 本文用 | 11px | 400 | 16px (×1.455) | normal | あり | メタ情報 |

### 3.5 行間・字間

**行間 (line-height)** — 実測値:
- body グローバル: `28px` (16px × **1.75**)
- 記事タイトル (h1): `52px` (32px × 1.625)
- 記事本文 (p): `28px` (16px × 1.75)
- 記事 h2: `28px` (18px × 1.556)
- WiredMono ラベル: `13px` (11px × 1.18) — タイトなモノスペース

**字間 (letter-spacing)** — 実測値:
- 本文 (p) / 見出し (h1, h2, h3): `normal`
- WiredMono ナビリンク: `0.92px` (11px × 0.083em) — 広めのトラッキング
- WiredMono セクションラベル: `0.564px` (12px × 0.047em)
- WiredMono バッジ: `1.1px` (11px × 0.1em) — 最も広いトラッキング

**ガイドライン**:
- 本文・見出し（和文）は `letter-spacing: normal` で `palt` のみ適用
- `WiredMono`（欧文ラベル）は `palt` なしで、代わりに広い `letter-spacing` でスペーシングを取る
- body の `line-height: 1.75` は note (1.5) や SmartHR (1.5) より広い。メディアサイトとして読みやすさを重視

### 3.6 禁則処理・改行ルール

```css
word-wrap: break-word;
```

- ブラウザデフォルトの禁則処理に依存

### 3.7 OpenType 機能

```css
/* body レベルでグローバル適用 — 全要素に継承 */
font-feature-settings: "palt";
```

- **palt はグローバル適用**: note（見出しのみ）と異なり、WIRED は body で `palt` を指定しているため、本文・見出し・リンクすべてに効いている
- **WiredMono には palt なし**: ブランドフォントは `font-feature-settings: normal` で、palt の影響を受けていない

### 3.8 縦書き

- 該当なし

---

## 4. Component Stylings

### Buttons / CTA Links

**Primary CTA（「詳細はこちら」等）**
- Background: `#000`
- Text: `#fff`
- Font Size: 12px
- Font Weight: 700
- Font Stack: 本文用

**Menu Button（ヘッダー）**
- Background: transparent
- Text: `#fff`（黒ヘッダー上）
- Font Size: 12px
- Font Weight: 700

**Consent Banner Button**
- Background: `#2b2e35`
- Text: `#fff`
- Border Radius: 6px
- Font: Inter, 14px, weight 600

### Cards（記事カード）

- Background: `#fff`
- 見出し: 20px–32px, weight 700, palt
- カテゴリラベル: WiredMono, 11px, letter-spacing 0.92px
- 区切り: ボーダーレスで余白とタイポグラフィで区切る

### Navigation

- Background: `#000`（メインヘッダー）
- Text: `#fff`（メニューボタン）
- Category Links: WiredMono, 11px, `#000`
- サイドナビ「SEE MORE STORIES」: WiredMono, 11px, weight 700, `#e5e5e5`

---

## 5. Layout Principles

### Content Width

- WIRED は Condé Nast のグローバルプラットフォームを使用
- 記事本文エリア: 中央寄せ、最大幅制限あり
- ヒーロー画像: 全幅ブリード

### Spacing

- 大きな余白を多用するマガジン型レイアウト
- 記事間の区切りは罫線ではなく余白で表現

---

## 6. Depth & Elevation

- CSS Custom Properties にシャドウ定義なし
- フラットデザイン。影やグラデーションをほぼ使わない
- 奥行きは画像のオーバーレイ（暗い透過）で表現

---

## 7. Do's and Don'ts

### Do（推奨）

- テキスト色は純粋な `#000` を使う（WIRED のブランドアイデンティティ）
- 本文テキストは `#1a1a1a` を使う（記事本文の実測値）
- `palt` は body レベルでグローバルに適用する
- `WiredMono` はナビゲーションとラベルにのみ使い、必ず広めの `letter-spacing` を付ける
- 見出しは大きく太く（32px / 700）。マガジン的な存在感を出す
- モノトーン（黒・白・グレー）を基調にする

### Don't（禁止）

- `WiredMono` を本文テキストに使わない（ブランドラベル専用）
- `WiredMono` に `palt` を適用しない（欧文モノスペースなので不要）
- 色を多用しない。WIRED は基本的にモノトーン
- カードやセクションに影（box-shadow）を使わない。フラットに保つ
- 游ゴシック Medium の `@font-face` マッピングは不要（font-family に直接 "游ゴシック Medium" を含めている）

---

## 8. Responsive Behavior

### Breakpoints

- Condé Nast グローバルプラットフォームの標準ブレイクポイントを使用
- CSS Custom Properties による独自ブレイクポイント定義なし

### ヘッダー

- デスクトップ: 黒背景ヘッダー + カテゴリナビ
- モバイル: ハンバーガーメニュー

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Text Primary: #000
Text Body: #1a1a1a
Text Meta: #757575
Background: #fff
Header Background: #000

Body Font: HelveticaNeue, "Helvetica Neue", Helvetica, Arial,
  游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium",
  游ゴシック, "Yu Gothic", "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN",
  "ヒラギノ角ゴ Pro W3", "Hiragino Kaku Gothic Pro", "MS ゴシック", "MS Gothic",
  sans-serif

Label Font: WiredMono, helvetica, sans-serif

Body: 16px / line-height: 1.75 / letter-spacing: normal / palt: global
Article Title: 32px / weight: 700 / line-height: 1.625
WiredMono Labels: 11px / letter-spacing: 0.083em / no palt
```

### プロンプト例

```
WIRED.jp のデザインに従って、テクノロジー記事一覧ページを作成してください。
- 本文フォント: HelveticaNeue, "Helvetica Neue", Helvetica, Arial,
    游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium",
    游ゴシック, "Yu Gothic", "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN",
    sans-serif
- テキスト色: #000（見出し）、#1a1a1a（本文）
- ヘッダー: 背景 #000、テキスト #fff
- カテゴリラベル: WiredMono（またはモノスペース）, 11px, letter-spacing: 0.083em, 大文字
- 記事タイトル: 32px, font-weight: 700, line-height: 1.625
- 本文: 16px, line-height: 1.75, font-feature-settings: "palt"
- 全体: モノトーン、フラット、影なし、マガジンレイアウト
```
