# DESIGN.md — freee

> freee（https://www.freee.co.jp/）のデザイン仕様書。
> freee Vibes Design System（https://vibes.freee.co.jp/）の公式デザイントークンおよびコーポレートサイトのCSSに基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 親しみやすく、明快な業務UI。複雑な会計・人事業務を、直感的で軽やかなインターフェースで提供する
- **密度**: プロダクトUIは中程度の情報密度。コーポレートサイトはゆったりとした余白
- **キーワード**: 親しみやすい、明快、信頼性、シンプル、アクセシブル
- **特徴**: ブルーを基調としたクリーンな配色。プロダクトUI（Vibes）とコーポレートサイトで異なるフォント戦略を持つ

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **Primary Blue** (`#2864f0`): メインのブランドカラー。CTAボタン、リンク、アクティブ状態
- **Primary Hover** (`#285ac8`): ホバー時のプライマリカラー
- **Primary Dark** (`#1e46aa`): プレス時・ダーク系アクセント
- **Primary Darkest** (`#143278`): 最も暗いブルー

### Blue Scale（P パレット）

`#ebf3ff` → `#dce8ff` → `#aac8ff` → `#73a5ff` → `#2864f0` → `#3264dc` → `#285ac8` → `#1e46aa` → `#23418c` → `#143278`

### Semantic（意味的な色）

- **Danger** (`#dc1e32`): エラー、削除、バリデーションエラー。ホバー: `#a51428`
- **Warning** (`#ffb91e`): 警告、注意喚起。ダーク: `#be8c14`
- **Success** (`#00963c`): 成功、完了
- **Orange** (`#fa6414`): 通知、アクセント

### Neutral（ニュートラル）

- **Text Primary** (`#323232`): 見出し、本文テキスト
- **Text Body** (`#595959`): body デフォルトテキスト色（実測: `rgb(89,89,89)`）
- **Text Muted** (`#8c8989`): プレースホルダー、ラベル（実測: `rgb(140,137,137)`）
- **Heading Blue** (`#1e46aa`): h3 見出し、キャプション強調（Primary Dark）

### Surface & Borders

- **White** (`#ffffff`): コンポーネントのベース背景
- **Background Light** (`#f7f5f5`): カード背景、セクション背景
- **Background Lighter** (`#f0eded`): 軽いグレー背景
- **Border** (`#e9e7e7`): 区切り線、ボーダー
- **Input Border** (`#e1dcdc`): フォーム入力欄の枠

---

## 3. Typography Rules

### 3.1 和文フォント

freee は2つのコンテキストで異なるフォント戦略を使用：

**プロダクトUI（Vibes）**: システムフォント
- ヒラギノ角ゴ ProN（macOS）
- メイリオ（Windows）

**コーポレートサイト**: Webフォント
- Noto Sans JP（Google Fonts）

### 3.2 欧文フォント

**プロダクトUI（Vibes）**:
- -apple-system, BlinkMacSystemFont（macOS システムフォント）
- Helvetica Neue（macOS）
- Arial（Windows フォールバック）

**コーポレートサイト**:
- Noto Sans（Google Fonts）
- museo-sans（一部モジュール）

### 3.3 font-family 指定

```css
/* プロダクトUI（Vibes Design System） */
font-family: '-apple-system', BlinkMacSystemFont, 'Helvetica Neue',
  'ヒラギノ角ゴ ProN', 'Hiragino Kaku Gothic ProN', Arial,
  'メイリオ', Meiryo, sans-serif;

/* コーポレートサイト（本文） */
font-family: "Noto Sans JP", sans-serif;

/* コーポレートサイト（一部モジュール） */
font-family: "Noto Sans", "Noto Sans JP", sans-serif;
```

**フォールバックの考え方（Vibes）**:
- システムフォントを最優先（macOS: -apple-system → Helvetica Neue → ヒラギノ角ゴ）
- 欧文フォントを和文フォントより先に指定（欧文の表示品質を優先）
- Windows: Arial → メイリオの順
- 最後に `sans-serif`

### 3.4 文字サイズ・ウェイト階層

**プロダクトUI（Vibes）**

| Role | Token | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|-------|------|--------|-------------|----------------|------|
| Heading 1 | FontSize1500 | 1.5rem (24px) | 700 | 1.5 | 0 | ページタイトル |
| Heading 2 | FontSize1000 | 1rem (16px) | 700 | 1.5 | 0 | セクション見出し |
| Heading 3 | FontSize0875 | 0.875rem (14px) | 700 | 1.5 | 0 | サブ見出し |
| Body | FontSize0875 | 0.875rem (14px) | 400 | 1.5 | 0 | 本文（標準） |
| Caption | FontSize0750 | 0.75rem (12px) | 400 | 1.5 | 0 | キャプション |
| Smallest | FontSize0625 | 0.625rem (10px) | 400 | 1.5 | 0 | アイコンラベル |

**コーポレートサイト** — computed style 実測値（2026-04-06）

| Role | Size | Weight | Line Height | Letter Spacing | Color | 備考 |
|------|------|--------|-------------|----------------|-------|------|
| H2 (hero) | 40px | 500 | 60px (×1.5) | 1.6px (0.04em) | `#323232` | ヒーローセクション見出し |
| H2 | 34px | 500 / 700 | 51px (×1.5) | 1.36px (0.04em) | `#323232` | セクション見出し |
| H2 (blue) | 24px | 500 | 36px (×1.5) | normal | `#2864f0` | ブルー見出し |
| H3 | 24px | 500 / 700 | 36px (×1.5) | normal | `#1e46aa` | サブ見出し（Primary Dark） |
| Body (p) | 16px | 400 | 24px (×1.5) | normal | `#323232` | 本文 |
| Body (secondary) | 16px | 400 | 24px (×1.5) | normal | `#595959` | 補足本文 |
| Label (p) | 18px | 700 | 27px (×1.5) | normal | `#2864f0` | ラベル強調 |
| Caption (p) | 12px | 700 | 18px (×1.5) | normal | `#1e46aa` | 小さい強調テキスト |
| Nav Link | 14px | 400 | 21px (×1.5) | normal | `#323232` | ヘッダーナビ |
| Footer Link | 13px | 400 | 19.5px (×1.5) | normal | `#595959` | フッターリンク |

> 注: 見出しの weight は **500**（medium）が多く、700（bold）は一部の強調見出しのみ。
> WebFetch で取得した値（700）とは異なる結果。

### 3.5 行間・字間

**行間 (line-height)**:
- プロダクトUI（Vibes）: すべて `1.5`（統一値）
- コーポレートサイト: 本文 `1.5`、見出し `1.15`〜`1.35`
- ボタン: `1.15`

**字間 (letter-spacing)**:
- プロダクトUI: `0`（デフォルト）
- コーポレートサイト見出し: `0.04em`〜`0.05em`
- ナビゲーション: `0.1em`
- 価格表示: `0.15em`〜`0.25em`
- タイトな表示: `-0.01em`

**ガイドライン**:
- プロダクトUIは一貫して `line-height: 1.5` を使用し、シンプルさを優先
- コーポレートサイトは文脈に応じて行間を変化させ、見出しはタイト、本文はゆったり

### 3.6 禁則処理・改行ルール

```css
overflow-wrap: break-word;
```

- Vibes Design System では特別な禁則処理の指定なし（ブラウザデフォルトに依存）

### 3.7 OpenType 機能

- デザイントークンに OpenType 機能の明示的な指定なし
- Noto Sans JP のデフォルトカーニングを使用

### 3.8 縦書き

- 該当なし。freee は横書きのみ

---

## 4. Component Stylings

### Buttons — computed style 実測値

> Vibes のトークン値（pill 型 `99rem`）と**コーポレートサイトの実測値が異なる**ことに注意

**Primary（コーポレートサイト）**
- Background: `#2864f0`
- Text: `#fff`
- Border: 2px solid `#2864f0`
- Border Radius: **8px**（Vibes の `99rem` ではない）
- Font Size: 16px
- Font Weight: 500 / 700（文脈で異なる）

**Secondary（ヘッダー）**
- Background: `#fff`
- Text: `#2864f0`
- Border: 1px solid `#2864f0`
- Border Radius: **5px**
- Font Size: 14px
- Font Weight: 700

**Danger**
- Background: `#dc1e32`
- Text: `#fff`
- Border Radius: 8px

### Inputs — computed style 実測値

- Background: `#fff`
- Border: 1px solid `#cccccc`（DESIGN.md の `#e1dcdc` とは異なる）
- Border Radius: **4px**（DESIGN.md の 8px とは異なる）
- Font Size: 16px
- Font Weight: 400
- Placeholder: weight 300, color `#8c8989`

### Cards

- Background: `#ffffff`
- Border Radius: 0.75rem (12px)
- Shadow: `0 0 1rem rgba(0,0,0,0.1), 0 0.125rem 0.25rem rgba(0,0,0,0.2)`

---

## 5. Layout Principles

### Spacing Scale（Vibes）

| Token | Value |
|-------|-------|
| XSmall | 0.25rem (4px) |
| Small | 0.5rem (8px) |
| Basic | 1rem (16px) |
| Large | 1.5rem (24px) |
| XLarge | 2rem (32px) |
| XXLarge | 3rem (48px) |

### Border Radius Scale（Vibes、セマンティック）

| Token | Value | 用途 |
|-------|-------|------|
| MiniPadding | 0.25rem (4px) | フォーカスリング等 |
| Base | 0.5rem (8px) | 入力欄、基本要素 |
| Card | 0.75rem (12px) | カード |
| Floating | 1rem (16px) | ポップアップ、フローティング |
| Dialog | 1.5rem (24px) | ダイアログ |
| Full | 99rem | ピル型ボタン |

### Container

- Max Width: 70rem (1120px)

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| Card | `0 0 1rem rgba(0,0,0,0.1), 0 0.125rem 0.25rem rgba(0,0,0,0.2)` | カード |
| Floating | `0 0 1.5rem rgba(0,0,0,0.1), 0 0.25rem 0.5rem rgba(0,0,0,0.2)` | フローティング要素 |
| Popup | `0 0 2rem rgba(0,0,0,0.1), 0 0.375rem 0.75rem rgba(0,0,0,0.2)` | ポップアップ、バルーン |

- すべてのシャドウはデュアルシャドウ（広い拡散 + 近い影）構成
- Transition: `0.2s`（インタラクティブ要素）、`0.3s`（フェード）

---

## 7. Do's and Don'ts

### Do（推奨）

- プロダクトUIとコーポレートサイトでフォント戦略が異なることを認識する
- プロダクトUIにはシステムフォントスタック（Vibes）を使い、Webフォントの読み込みを避ける
- コーポレートサイトのボタンは `border-radius: 8px`。Vibes のピル型（`99rem`）はプロダクトUI用
- 見出しの weight は `500`（medium）を基本とし、強調時のみ `700` を使う
- スペーシングは 4px の倍数に揃える（Vibes の spacing scale に準拠）
- 色のコントラスト比は WCAG AA 以上を確保する

### Don't（禁止）

- コーポレートサイトのフォント（Noto Sans JP）をプロダクトUIに使わない（パフォーマンスに影響）
- プロダクトUIで `border-radius` を角型（0px）にしない。Vibes のラジアススケールに従う
- テキスト色に純粋な `#000000` を使わない。`#323232` を使用する
- ブランドブルー `#2864f0` の上に暗い色のテキストを置かない（コントラスト不足）
- コーポレートサイトの大見出し（34px以上）では `letter-spacing: 0.04em` を使う。24px以下の見出しは `normal`
- body のデフォルトテキスト色は `#595959` であり `#323232` ではない（`#323232` は見出し・本文強調用）

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 説明 |
|------|-------|------|
| Narrow Mobile | ≤ 375px | 狭いモバイル |
| Mobile | ≤ 768px | モバイル |
| Tablet | ≤ 1024px | タブレット |
| Desktop | > 1024px | デスクトップ |

### モバイル対応

- プロダクトUI: 見出しサイズが圧縮される（H1: 1rem、H2: 0.875rem、H3: 0.875rem）
- ボタンの高さはモバイルでも維持（タッチターゲット確保）

### タッチターゲット

- 最小サイズ: 36px（Vibes デフォルト。Small ボタンは 24px だがタッチ対象の場合は注意）

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Primary Color: #2864f0
Heading Blue: #1e46aa
Text Heading: #323232
Text Body (default): #595959
Background: transparent (白ページ上)
Surface: #ffffff
Border: #e9e7e7
Input Border: #cccccc（実測値）
Danger: #dc1e32
Success: #00963c

Product UI Font: '-apple-system', BlinkMacSystemFont, 'Helvetica Neue',
  'ヒラギノ角ゴ ProN', 'Hiragino Kaku Gothic ProN', Arial,
  'メイリオ', Meiryo, sans-serif
Website Font: "Noto Sans JP", sans-serif

Body Size (Product): 14px
Body Size (Website): 16px
Line Height: 1.5（全体統一）
Heading Weight: 500（medium）、強調時 700
Button Radius (Website): 8px
Button Radius (Product): 99rem (pill)
Input Radius: 4px
```

### プロンプト例

```
freee のコーポレートサイト風に、請求書一覧画面を作成してください。
- フォント: "Noto Sans JP", sans-serif
- テキスト色: #595959（body）、#323232（見出し・強調）
- 見出し: weight 500、大見出し（34px以上）は letter-spacing: 0.04em
- h3 等のサブ見出し: #1e46aa（ブルー）
- プライマリボタン: 背景 #2864f0、テキスト #fff、角丸 8px、border: 2px solid #2864f0
- 入力欄: ボーダー #cccccc、角丸 4px
- カード: 角丸 16px
- スペーシング: 4px の倍数
```
