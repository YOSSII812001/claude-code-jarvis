# DESIGN.md — Apple Japan

> Apple Japan（https://www.apple.com/jp/）のデザイン仕様書。
> Puppeteer による computed style 実測値（2026-04-06 取得）に基づく。
> 本家 awesome-design-md の apple DESIGN.md との差分に焦点を当てる。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: Apple グローバルと同一のミニマルデザイン。製品を主役にし、タイポグラフィと余白で構成するマガジンレイアウト
- **密度**: 非常にゆったり。大きなヒーロー画像と見出しが画面いっぱいに広がる
- **キーワード**: ミニマル、プレミアム、製品中心、白黒基調、大胆なタイポグラフィ
- **日本語版の特徴**: `SF Pro JP` というApple独自の日本語フォントが最優先で使用される。英語版の `SF Pro Display` / `SF Pro Text` よりも前に配置

---

## 2. Color Palette & Roles

> 英語版と同一のカラーパレット

### Primary

- **Near Black** (`#1d1d1f`): プライマリテキスト。Apple は純粋な `#000` ではなくこの色を使う
- **Pure Black** (`#000`): ヒーロー背景、ダークセクション
- **White** (`#fff`): ページ背景、ダーク上のテキスト
- **Light Gray** (`#f5f5f7`): セクション背景（交互配置）

### Interactive

- **Apple Blue** (`#0071e3`): CTA ボタン、フォーカスリング（`--sk-focus-color`）
- **Link Blue** (`#0066cc`): テキストリンク（`--sk-body-link-color`）
- **Bright Blue** (`#2997ff`): ダーク背景上のリンク

### Text（opacity ベース）

- **Primary** (`#1d1d1f` / `rgba(0,0,0,0.88)`): 本文テキスト
- **Secondary** (`rgba(0,0,0,0.56)`): カルーセルボタン等
- **Nav Text** (`rgba(0,0,0,0.8)`): グローバルナビ
- **On Dark** (`#f5f5f7` / `rgba(255,255,255,0.92)`): ダーク背景上テキスト

### Surface

- **Nav Background** (`rgba(0,0,0,0.8)`): グローバルナビ背景（すりガラス）
- **Nav Opened** (`#fafafc`): ナビ展開時
- **Glyph Gray Secondary** (`#6e6e73`): セカンダリグリフ

---

## 3. Typography Rules

### 3.1 和文フォント

- **SF Pro JP**: Apple 独自の日本語フォント。apple.com/jp で最優先指定
- **ヒラギノ角ゴ Pro**: macOS フォールバック（`Hiragino Kaku Gothic Pro` / `ヒラギノ角ゴ Pro W3`）
- **メイリオ / Meiryo**: Windows フォールバック
- **MS Pゴシック**: レガシー Windows フォールバック

### 3.2 欧文フォント

- **SF Pro Display**: 大見出し用（20px 以上）
- **SF Pro Text**: 本文用（19px 以下）
- **SF Pro Icons**: アイコングリフ
- **Helvetica Neue / Helvetica / Arial**: 一般フォールバック

### 3.3 font-family 指定

> 英語版との最大の差分。`SF Pro JP` が全スタックの先頭に追加されている

```css
/* 本文用（Text） */
font-family: "SF Pro JP", "SF Pro Text", "SF Pro Icons",
  "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
  メイリオ, Meiryo, "ＭＳ Ｐゴシック",
  "Helvetica Neue", Helvetica, Arial, sans-serif;

/* 見出し用（Display） */
font-family: "SF Pro JP", "SF Pro Display", "SF Pro Icons",
  "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
  メイリオ, Meiryo, "ＭＳ Ｐゴシック",
  "Helvetica Neue", Helvetica, Arial, sans-serif;

/* フッターナビ用 */
font-family: "SF Pro JP", "SF Pro Text", "Apple TP", "Myriad Set Pro",
  "SF Pro Icons", "Apple Legacy Icons",
  "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
  "Apple TP CommonT", メイリオ, Meiryo,
  "Helvetica Neue", Helvetica, Arial, sans-serif;
```

**英語版との差分**:
- 英語版: `SF Pro Display` / `SF Pro Text` が先頭
- 日本語版: `SF Pro JP` が先頭に追加。日本語グリフの表示品質を最優先
- 和文フォールバック: ヒラギノ角ゴ Pro → メイリオ → MS Pゴシック
- 一部の製品名見出し（"MacBook Air" 等の英語のみ）は `SF Pro JP` なしで `SF Pro Display` を直接使用

### 3.4 文字サイズ・ウェイト階層

> computed style 実測値

**トップページ**

| Role | Font Stack | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|-----------|------|--------|-------------|----------------|------|
| Hero Display (最大) | Display | 108px | 600 | 115.56px (×1.07) | 2.16px (0.02em) | 学割キャンペーン等 |
| Hero Display (大) | Display | 64px | 600 | 67.2px (×1.05) | normal | ヒーローキャッチ |
| Hero Display (中) | Display | 53px | 600 | 55.65px (×1.05) | -0.53px | サブヒーロー |
| Section Heading | Display | 40px | 600 | 44px (×1.10) | normal | 製品名（h3） |
| Subtitle | Display | 28px | 400 | 32px (×1.14) | 0.196px | 説明文（大） |
| Subtitle (small) | Display | 21px | 400 | 26px (×1.24) | 0.231px | 説明文（小） |
| Body | Text | 17px | 400 | 25px (×1.47) | -0.357px | 本文 |
| Caption | Text | 14px | 400 | 20.6px (×1.47) | normal | 価格表示等 |
| Nav Link | Text | 12px | 400 | 12px (×1.0) | normal | グローバルナビ |
| Footer Category | Text | 12px | 400 | 17px (×1.42) | normal | フッターカテゴリ |

**iPhone ページ**

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Page Title (h1) | 80px | 600 | 87px (×1.09) | normal | "iPhone" |
| Section Heading | 28px | 600 | 33px (×1.18) | 0.196px | 「新しいルック。」等 |
| Body | 17px | 400 | 23px (×1.35) | normal | 製品説明 |
| Body Emphasis | 17px | 600 | 23px (×1.35) | normal | 価格表示 |
| Caption | 14px | 400 / 600 | 19.8px (×1.42) | normal | 補足情報 |
| Product Name | 19.89px | 600 | 26.9px (×1.35) | normal | "iPhone 17 Pro" 等 |

### 3.5 行間・字間

**行間 (line-height)** — 実測値:
- body: `25px` (17px × 1.47)
- Hero Display: `×1.05`〜`×1.10` — 非常にタイト
- Section Heading: `44px` (40px × 1.10)
- Subtitle: `32px` (28px × 1.14)
- Body: `25px` (17px × 1.47) / iPhone ページでは `23px` (17px × 1.35)
- Nav: `12px` (12px × 1.0) — 1行分ちょうど

**字間 (letter-spacing)** — 実測値:
- body: `-0.357px` — **負のトラッキング**（Apple の特徴）
- Hero 108px: `2.16px` (0.02em) — 巨大サイズのみ正のトラッキング
- Hero 53px: `-0.53px` — 負のトラッキング
- Subtitle 28px: `0.196px` — わずかに正
- Subtitle 21px: `0.231px` — わずかに正
- Section Heading 40px: `normal`
- Nav / Caption: `normal`

**ガイドライン**:
- Apple は基本的に**負の letter-spacing** を使う（文字を詰める方向）
- 大サイズの見出し（50px以上）ではサイズに応じて正負が変わる
- 小さいテキスト（14px以下）は `normal`

### 3.6 禁則処理・改行ルール

- ブラウザデフォルトの禁則処理に依存
- 日本語テキストに `word-break` の明示的な指定なし

### 3.7 OpenType 機能

```css
/* 全要素で palt なし */
font-feature-settings: normal;
```

- **palt は使用していない**: SF Pro JP 自体が日本語の字詰めを内蔵しているため、追加の OpenType 機能は不要
- 英語版と同様、`font-feature-settings` はすべて `normal`

### 3.8 縦書き

- 該当なし

---

## 4. Component Stylings

### Buttons

**Primary CTA（"購入する" 等）**
- Background: `#0071e3`（Apple Blue）
- Text: `#fff`
- Border Radius: 980px（完全ピル型）
- Font Size: 17px
- Font Weight: 400
- Padding: 8px 22px

**Outline（"詳しく見る" 等）**
- Background: transparent
- Text: `#0071e3`
- Border: 1px solid `#0071e3`
- Border Radius: 980px

**Dark Fill**
- Background: `#1d1d1f`
- Text: `#fff`
- Border Radius: 8px

**Nav CTA（"購入する"ナビ内）**
- Background: `#0071e3`
- Text: `#fff`
- Border Radius: 980px
- Font Size: 12px

### Navigation

- Background: `rgba(0,0,0,0.8)` + `backdrop-filter: saturate(180%) blur(20px)`（すりガラス）
- Height: 44px（`--r-globalnav-height`）
- Text: `rgba(0,0,0,0.8)`
- Font Size: 12px（カテゴリリンク）

---

## 5. Layout Principles

### Content Width（CSS Custom Properties 実測値）

| Token | Value | 用途 |
|-------|-------|------|
| `--global-content-max-width-hero` | 1680px | ヒーローセクション |
| `--global-content-max-width` | 1260px | 通常コンテンツ |

### Breakpoints（実測値）

| Name | Width | 用途 |
|------|-------|------|
| Large | ≥ 1024px | デスクトップ |
| Medium | 834px–1023px | タブレット |
| Small | 320px–833px | モバイル |

---

## 6. Depth & Elevation

- **Nav Glass**: `rgba(0,0,0,0.8)` + `backdrop-filter: saturate(180%) blur(20px)` — すりガラスナビ
- **Card Shadow**: `rgba(0,0,0,0.22) 3px 5px 30px 0px`
- **Focus Ring**: `0 0 0 3px rgba(0,113,227,0.2)` — Apple Blue の透過リング
- 基本的にフラット。影は hover 時のカードに限定

---

## 7. Do's and Don'ts

### Do（推奨）

- `SF Pro JP` をフォントスタックの先頭に配置する（英語版との最大の差分）
- テキスト色は `#1d1d1f` を使う（`#000` ではない）
- 本文に負の `letter-spacing`（`-0.357px`）を適用する
- ボタンは 980px のピル型を基本とする
- `palt` は使わない（SF Pro JP が内蔵の字詰めを持つ）
- ナビにはすりガラス効果（`backdrop-filter`）を使う
- 製品名が英語のみの場合は `SF Pro Display` を直接使用しても良い

### Don't（禁止）

- 英語版のフォントスタック（`SF Pro Display` 先頭）をそのまま使わない。日本語版は `SF Pro JP` が先頭
- `palt` や `font-feature-settings` を追加しない（SF Pro JP に不要）
- ヒラギノ角ゴ **ProN** を使わない。Apple JP サイトは **Pro**（ProN ではない）を使用
- ダーク背景のテキストに純粋な `#fff` を使わない。`#f5f5f7` または `rgba(255,255,255,0.92)` を使う
- 正の `letter-spacing` を本文に使わない（Apple は詰める方向が基本）

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 説明 |
|------|-------|------|
| Large | ≥ 1024px | デスクトップ |
| Medium | 834px–1023px | タブレット |
| Small | 320px–833px | モバイル |

### ナビゲーション

- Large: テキストリンクのカテゴリナビ
- Small: ハンバーガーメニュー（展開時背景 `#fafafc`）

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Text Primary: #1d1d1f
Text On Dark: #f5f5f7
Background: #fff
Section Background: #f5f5f7
Hero Background: #000
Apple Blue: #0071e3
Link Blue: #0066cc
Nav: rgba(0,0,0,0.8) + backdrop-filter: blur(20px)

Text Font: "SF Pro JP", "SF Pro Text", "SF Pro Icons",
  "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
  メイリオ, Meiryo, "ＭＳ Ｐゴシック",
  "Helvetica Neue", Helvetica, Arial, sans-serif

Display Font: "SF Pro JP", "SF Pro Display", "SF Pro Icons",
  "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
  メイリオ, Meiryo, "ＭＳ Ｐゴシック",
  "Helvetica Neue", Helvetica, Arial, sans-serif

Body: 17px / weight: 400 / line-height: 1.47 / letter-spacing: -0.357px
Heading: 40px / weight: 600 / line-height: 1.10
Button: pill (980px radius) / Apple Blue
palt: 不使用（SF Pro JP 内蔵）
Content Max Width: 1260px / Hero: 1680px
```

### プロンプト例

```
Apple Japan のデザインに従って、製品紹介ページを作成してください。
- フォント: "SF Pro JP", "SF Pro Display", "Hiragino Kaku Gothic Pro",
    "ヒラギノ角ゴ Pro W3", メイリオ, Meiryo, sans-serif
- テキスト色: #1d1d1f（純粋な黒は使わない）
- ダーク背景テキスト: #f5f5f7
- 本文: 17px, line-height: 1.47, letter-spacing: -0.357px
- 見出し: SF Pro Display, 40px, weight 600, line-height: 1.10
- ボタン: Apple Blue #0071e3, 角丸 980px（ピル型）
- ナビ: すりガラス rgba(0,0,0,0.8) + backdrop-filter: blur(20px)
- palt は使わない
- ヒラギノ角ゴは Pro（ProN ではない）
```
