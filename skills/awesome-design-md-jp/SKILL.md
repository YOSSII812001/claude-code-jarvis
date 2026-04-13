---
name: awesome-design-md-jp
description: "23社の日本企業/日本語UIサービスのデザインシステム（DESIGN.md）を参照してUI実装。日本語タイポグラフィ特化（和文フォント・禁則処理・palt/kern・混植ルール・縦書き対応）。SmartHR、freee、LINE、メルカリ、楽天、食べログ、pixiv、Zenn、Qiita等。「〇〇風のデザインで」「日本語UIを正しく」で発動。"
metadata:
  priority: 8
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
      - "awesome-design-md-jp"
      - "日本語デザインシステム"
      - "日本語タイポグラフィ"
      - "日本語組版"
      - "和文フォント"
      - "和欧混植"
      - "約物半角"
      - "禁則処理"
      - "SmartHR風"
      - "freee風"
      - "LINE風"
      - "ライン風"
      - "メルカリ風"
      - "楽天風"
      - "食べログ風"
      - "pixiv風"
      - "Zenn風"
      - "Qiita風"
      - "note風"
      - "MUJI風"
      - "無印風"
      - "ABEMA風"
      - "クックパッド風"
      - "マネーフォワード風"
      - "サイボウズ風"
      - "Sansan風"
      - "STUDIO風"
      - "connpass風"
      - "Toyota風"
      - "トヨタ風"
      - "WIRED風"
      - "ワイヤード風"
      - "Novasell風"
      - "ノバセル風"
      - "Notion風"
      - "ノーション風"
      - "Apple風"
      - "アップル風"
      - "日本語UI"
      - "日本のサービス風"
      - "日本語サイト"
      - "Japanese design"
      - "Japanese typography"
      - "CJKフォント"
      - "游ゴシック"
      - "Noto Sans JP"
      - "ヒラギノ"
      - "palt"
    allOf: []
    anyOf: []
    noneOf:
      - "翻訳"
      - "自然言語処理"
      - "文字コード"
      - "フォントインストール"
    minScore: 6
---

# Awesome Design MD JP — 日本語UIデザインシステムリファレンス

> Source: [kzhrknt/awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) (MIT License)
> 日本語UIをAIエージェントに正しくつくらせるための、23社の実在日本企業サイトから抽出されたDESIGN.md集。

## 概要

英語版 `awesome-design-md` の日本語特化版。最大の違いは **Typography セクションが8サブセクションに拡張** されている点:

### 9セクション構成（セクション3が核心）

1. **Visual Theme & Atmosphere** — ムード・密度・デザイン方針
2. **Color Palette & Roles** — Primary / Semantic / Neutral のhexテーブル
3. **Typography Rules** — **★ 日本語特化8サブセクション:**
   - 3.1 和文フォント（ゴシック体 / 明朝体）
   - 3.2 欧文フォント（サンセリフ / セリフ / 等幅）
   - 3.3 font-family指定（CSSコードブロック + フォールバックチェーン設計思想）
   - 3.4 文字サイズ・ウェイト階層（テーブル形式）
   - 3.5 行間・字間（line-height / letter-spacing の具体値 + 日本語ガイドライン）
   - 3.6 禁則処理・改行ルール（word-break / line-break のCSS + 禁則対象文字列）
   - 3.7 OpenType機能（palt / kern の使用/不使用判断）
   - 3.8 縦書き（writing-mode: vertical-rl 対応の有無）
4. **Component Stylings** — ボタン / 入力欄 / カード・テーブル
5. **Layout Principles** — スペーシングスケール / Container / Grid
6. **Depth & Elevation** — Shadow レベルテーブル
7. **Do's and Don'ts** — デザインガードレール（日本語記述）
8. **Responsive Behavior** — Breakpoints / タッチターゲット
9. **Agent Prompt Guide** — クイックリファレンス + プロンプト例

## 利用可能な企業カタログ（23社）

| カテゴリ | 企業 | ディレクトリ名 |
|---------|------|---------------|
| **HR SaaS** | SmartHR | `smarthr` |
| **Fintech SaaS** | freee | `freee` |
| **Fintech** | MoneyForward | `moneyforward` |
| **メッセンジャー** | LINE | `line` |
| **C2Cマーケットプレイス** | Mercari | `mercari` |
| **EC** | 楽天 | `rakuten` |
| **グルメ** | 食べログ | `tabelog` |
| **クリエイタープラットフォーム** | pixiv | `pixiv` |
| **テック記事** | Zenn | `zenn` |
| **開発者コミュニティ** | Qiita | `qiita` |
| **メディアプラットフォーム** | note | `note` |
| **レシピ / UGC** | Cookpad | `cookpad` |
| **グループウェア** | Cybozu | `cybozu` |
| **名刺SaaS** | Sansan | `sansan` |
| **テックイベント** | connpass | `connpass` |
| **ノーコードデザイン** | STUDIO | `studio` |
| **動画ストリーミング** | ABEMA | `abema` |
| **テックメディア** | WIRED.jp | `wired` |
| **AI Agency** | Novasell | `novasell` |
| **リテール / ライフスタイル** | MUJI (無印良品) | `muji` |
| **自動車** | Toyota | `toyota` |
| **生産性ツール** | Notion (JP) | `notion` |
| **Consumer Tech** | Apple Japan | `apple` |

## 英語版 awesome-design-md との使い分け

| 観点 | 英語版 (`awesome-design-md`) | 日本語版 (`awesome-design-md-jp`) |
|------|----------------------------|--------------------------------|
| 対象 | 欧米企業58+社 | 日本企業/日本語UI 23社 |
| Typography | 基本的なfont-family/size/weight | **8サブセクション**: 和文・禁則・palt・混植 |
| CJK対応 | なし | **核心機能** |
| 用途 | グローバルUI、英語圏サービス風 | 日本語UI、日本のサービス風 |

**併用ルール:**
- 日本語UIを作る場合 → **こちら（JP版）を優先**
- グローバル企業風（Stripe, Vercel等）→ 英語版を使用
- 日本語UI + グローバル企業風 → 英語版のカラー/レイアウト + **JP版の Typography セクション3 を必ず適用**

## ワークフロー

### Step 1: 企業名を特定

ユーザーの要望から参照すべき企業を特定する。

- 「SmartHR風の管理画面」→ smarthr
- 「食べログっぽいレビューUI」→ tabelog
- 「Zennみたいな記事ページ」→ zenn
- 「無印良品のような落ち着いたデザイン」→ muji
- 「日本語でモダンなSaaS管理画面」→ smarthr, freee, moneyforward 等を提案

### Step 2: DESIGN.mdを読み込む

```
~/.claude/skills/awesome-design-md-jp/repo/design-md/{company}/DESIGN.md
```

**企業名→ディレクトリ名マッピング:**
- 食べログ → `tabelog`
- クックパッド → `cookpad`
- マネーフォワード → `moneyforward`
- サイボウズ → `cybozu`
- 無印良品 / MUJI → `muji`
- トヨタ → `toyota`
- その他 → 小文字変換（SmartHR → `smarthr`）

### Step 3: Typography Rules を企業別に適用

DESIGN.mdのセクション3を**そのまま**読み取り、企業ごとの値を正確に適用する。
**一般論で上書きしない** -- 楽天(lh:1.1)やSansan(lh:1.0)のように意図的に標準から外れた設計もある。

1. **3.3 font-family**: CSSコードブロックをそのままコピー（フォールバックチェーン順序を変えない）
2. **3.5 line-height / letter-spacing**: role別テーブルの具体値をそのまま適用
3. **3.6 禁則処理・改行**: `word-break` / `line-break` / `overflow-wrap` のCSS組み合わせを確認
4. **3.7 OpenType機能**: `palt` / `kern` / YakuHan / `font-kerning` の使用/不使用を確認
5. **和欧混植**: 本文・コード・数値・ラベルを分けてフォント指定が必要か確認
6. **環境固有対策**: SmartHR系のAdjustedYuGothic等、企業固有のworkaroundがあれば適用

**注意**: フォントが利用不可な場合（Webフォント未導入、ライセンス制約等）は、DESIGN.md内のフォールバックチェーンに従って次候補を使用する。system-uiやsans-serifへのdegradationは許容される。

### Step 4: デザイントークンを抽出・適用

DESIGN.mdから以下を抽出してコードに反映:

1. **カラー変数**: CSS custom properties or Tailwind config
2. **タイポグラフィ**: font-family（和文+欧文）, font-weight, line-height, letter-spacing
3. **スペーシング**: base unit, spacing scale（CSS Custom Properties形式が多い）
4. **シャドウ**: box-shadow値
5. **border-radius**: コンポーネント別の角丸値
6. **ブレークポイント**: レスポンシブ設定

### Step 5: コンポーネント実装

DESIGN.mdのComponent Stylingセクションに従い:
- ボタン（Primary / Secondary / Ghost）
- カード（背景色、ボーダー、影）
- 入力欄（ボーダー、フォーカスリング）
- テーブル（日本語情報密度に配慮）

## 各企業の特徴的なデザイン知識（全23社）

| 企業 | 特記事項 |
|------|---------|
| SmartHR | AdjustedYuGothic @font-face トリック、Stone系ウォームグレー、ブランド色はUIに使わずProduct Main #0077c7 |
| freee | SaaS管理画面の標準的日本語タイポグラフィ |
| MoneyForward | body 14px、ヒラギノ角ゴ Pro和文優先、weight 500 |
| LINE | body 20px（大きい）、LINE Green #06c755、KRフォールバック |
| Mercari | C2Cマーケットプレイス向けレイアウト |
| Rakuten | body 12px / lh:1.1（情報密度の極致）、メイリオ先頭 |
| Tabelog | body 12px、メイリオ日本語名先頭、食べログオレンジ #f09000 |
| pixiv | system-ui スタック、#0096fa、CSS vars 114件 |
| Zenn | lh:1.8、rgba色、Qiitaとの比較セクション付き |
| Qiita | YakuHanJPs先頭（約物半角化）、rgba opacity色、lh:1.8 |
| note | メディアプラットフォーム向け可読性重視レイアウト |
| Cookpad | noto-sans(Adobe)、負letter-spacing -0.4px、liga対応 |
| Cybozu | lh:2.0グローバル適用、ヒラギノ角ゴ日本語名先行 |
| Sansan | helvetica小文字先頭、body lh:1.0、Sansan Navy #042a6d |
| connpass | Lucida Grande先頭（珍しい）、見出し weight 400 |
| STUDIO | ノーコードデザインツール、クリエイター向けUI |
| ABEMA | BIZ UDPGothic、ダーク基調、CSS vars 844件（最多） |
| WIRED.jp | テックメディア、ライト/ダーク対応 |
| Novasell | AI Agency向け先進的デザイン |
| MUJI | きなり色 #f4eede、lh:1.6統一、palt不使用、border-radius: 0px |
| Toyota | SF Pro先頭、letter-spacing 0.04em グローバル適用 |
| Notion (JP) | NotionInter、font-feature-settings: "lnum"、ダーク基調、CSS vars 408件 |
| Apple Japan | SF Pro先頭、日本語タイポグラフィ対応のグローバルデザイン |

## 既存スキルとの連携

| スキル | 連携方法 |
|--------|---------|
| `awesome-design-md`（英語版） | カラー/レイアウトは英語版、日本語タイポグラフィはJP版から |
| `frontend-skill` | JP版DESIGN.mdトークンをVisual Thesisに組み込む |
| `ui-ux-pro-max` | 日本語フォント設定をDESIGN.mdから上書き |
| `ux-psychology` | UX原則はux-psychology、ビジュアル仕様はDESIGN.mdから |
| `liftkit` | LiftKitテーマのカスタムカラー/フォントにDESIGN.mdの値を適用 |

## ガイドライン

- **忠実度**: DESIGN.mdの色コード・フォントサイズ・font-family・禁則CSS はそのまま使用する（独自解釈しない）
- **日本語タイポグラフィ最優先**: 日本語UIでは Typography セクション3 のサブセクションを必ずすべて確認・適用する
- **フォールバックチェーン尊重**: font-family の和文/欧文フォールバック順序は原則変更しない。ただしWebフォント未導入やライセンス制約がある場合は、チェーン内の次候補フォントへ graceful degradation する
- **不足時**: DESIGN.mdにない要素は、同じデザイン言語の延長で補完する
- **ミックス**: 複数企業のDESIGN.mdを組み合わせる場合、カラーは1社に統一、タイポグラフィは1社に統一するのが安全
- **更新**: `git -C ~/.claude/skills/awesome-design-md-jp/repo pull` で最新版を取得可能

## 使用例

```
ユーザー: 「SmartHR風のHR管理ダッシュボードを作って」
→ smarthr/DESIGN.md を読み込み
→ AdjustedYuGothic + Stone系ウォームグレー + Product Main #0077c7 を適用
→ 禁則処理CSS + palt設定を確認・反映
→ コンポーネントをSmartHR仕様で実装

ユーザー: 「Zennみたいなブログ記事ページがほしい」
→ zenn/DESIGN.md を読み込み
→ lh:1.8 + rgba色 + タイポグラフィ階層を適用
→ 記事本文の可読性重視レイアウトを構成

ユーザー: 「Vercelっぽいデザインだけど日本語が綺麗に表示されるLP」
→ 英語版 vercel/DESIGN.md（カラー・レイアウト・影）
→ JP版から日本語タイポグラフィルール（例: smarthr or muji のセクション3）を組み合わせ
```

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-08 | 初版作成 | kzhrknt/awesome-design-md-jp リポジトリをスキル化 |
| 2026-04-08 | Codexレビュー反映: トリガー補強（Notion/Apple/日本語エイリアス追加、noneOf設定）、Step 3再設計（一般論→企業別値読み取り方式）、特徴表全23社化、フォールバック方針改善、英語版社数修正 | Codex品質レビュー（GPT-5.4）による指摘対応 |
