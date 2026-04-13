<!-- 抽出元: SKILL.md - デザインシステム原則、タイポグラフィシステム、カラーシステム、ダークモード、レスポンシブデザイン セクション -->

# LiftKit デザインシステム詳細

## 黄金比スケーリング

グローバルスケールファクター: `--lk-scalefactor: 1.618`

**ステップ計算:**
| CSS変数 | 値 | 計算 |
|---------|-----|------|
| `--lk-wholestep` | 1.618 | = scalefactor |
| `--lk-halfstep` | 1.272 | = √wholestep |
| `--lk-quarterstep` | 1.128 | = √halfstep |
| `--lk-eighthstep` | 1.062 | = √quarterstep |
| `--lk-wholestep-dec` | 0.618 | = wholestep - 1 |
| `--lk-halfstep-dec` | 0.272 | = halfstep - 1 |
| `--lk-quarterstep-dec` | 0.128 | = quarterstep - 1 |
| `--lk-eighthstep-dec` | 0.062 | = eighthstep - 1 |

## サイズスケール（LkSizeUnit）

基準: `--lk-size-md: 1em`（ルートfont-size: 16px）

| トークン | 計算 | 概算値 |
|---------|------|--------|
| `--lk-size-3xs` | md / φ³ | ~0.236em |
| `--lk-size-2xs` | md / φ² | ~0.382em |
| `--lk-size-xs` | md / φ | ~0.618em |
| `--lk-size-sm` | md / φ | ~0.618em |
| `--lk-size-md` | 1em | 1em (16px) |
| `--lk-size-lg` | md × φ | ~1.618em |
| `--lk-size-xl` | lg × φ | ~2.618em |
| `--lk-size-2xl` | xl × φ | ~4.236em |
| `--lk-size-3xl` | 2xl × φ | ~6.854em |
| `--lk-size-4xl` | 3xl × φ | ~11.09em |

**型:** `LkSizeUnit = "3xs" | "2xs" | "xs" | "sm" | "md" | "lg" | "xl" | "2xl" | "3xl" | "4xl"`

## シャドウスケール

```css
--shadow-sm: 0 0 1px 0 var(--lk-shadow);
--shadow-md: 0 4px 6px rgba(0,0,0,0.08), 0 2px 4px rgba(0,0,0,0.11), 0 0 1px rgba(0,0,0,0.4);
--shadow-lg: 0 11px 15px -3px rgba(0,0,0,0.11), 0 2px 6px rgba(0,0,0,0.07), 0 0 1px rgba(0,0,0,0.4);
--shadow-xl: 0px 0px 1px 0px var(--lk-outline), 0px 50px 100px 0px rgba(0,0,0,0.15);
--shadow-2xl: 0 25px 50px rgba(0,0,0,0.23), 0 9px 18px rgba(0,0,0,0.1), 0 0 1px rgba(0,0,0,0.4);
```

## 光学補正（Optical Correction）

人間の目の知覚に合わせた自動調整:
- **Card:** `opticalCorrection` propで行間による余分なパディングを補正。オフセット値はフォントクラスごとに計算:
  ```css
  --body-offset: calc(var(--body-font-size) / var(--lk-wholestep));
  --display1-offset: calc(var(--display1-font-size) * calc(var(--display1-line-height) / var(--lk-wholestep)));
  ```
- **Button:** `opticIconShift` propでアイコンを微調整（デフォルトON）
- **フォント:** `-webkit-font-smoothing: antialiased` 自動適用

## マテリアルスタイル

**`LkMaterial = "flat" | "glass" | "rubber"`**

| マテリアル | 説明 |
|-----------|------|
| `flat` | フラットなソリッド表面（デフォルト）。`bgColor` で背景色指定 |
| `glass` | ガラスモーフィズム（背景ブラー効果） |
| `rubber` | ラバー質感 |

**Glass Material Props:**
```typescript
interface LkMatProps_Glass {
  thickness?: "thick" | "normal" | "thin";  // blur量を制御
  // thick: blur=var(--lk-size-lg), opacity=0.8
  // normal: blur=var(--lk-size-md), opacity=0.6
  // thin: blur=var(--lk-size-xs), opacity=0.4
  tint?: LkColor;           // ティントカラー
  tintOpacity?: number;      // デフォルト: 0.2
  light?: boolean;           // 光沢レイヤー追加
  lightExpression?: string;  // CSSグラデーション（mix-blend-mode: soft-light）
}
```

## タイポグラフィシステム

### フォントクラス（LkFontClass）

すべて黄金比スケールファクターから導出。3ファミリー: regular, bold, mono。

**Regular:**
| クラス | フォントサイズ | 行高 | 字間 | ウェイト |
|--------|-------------|------|------|---------|
| `display1` | 1em × φ³ | 1.128 | -0.022em | 400 |
| `display2` | 1em × φ² | 1.272 | -0.022em | 400 |
| `title1` | 1em × φ × √φ | 1.272 | -0.022em | 400 |
| `title2` | 1em × φ | 1.272 | -0.02em | 400 |
| `title3` | 1em × √φ | 1.272 | -0.017em | 400 |
| `heading` | 1em × ⁴√φ | 1.272 | -0.014em | 600 |
| `subheading` | 1em / ⁴√φ | 1.272 | -0.007em | 400 |
| `body` | 1em | 1.618 | -0.011em | 400 |
| `callout` | 1em / ⁸√φ | 1.272 | -0.009em | 400 |
| `label` | (1em / ⁴√φ) / ⁸√φ | 1.272 | -0.004em | 600 |
| `caption` | 1em / √φ | 1.272 | -0.007em | 400 |
| `capline` | 1em / √φ | 1.272 | 0.0618em | 400 (uppercase) |

**Bold:** 同サイズ、weight 600-700。クラス名: `display1-bold`, `display2-bold` 等
**Mono:** クラス名: `display1-mono`, `display2-mono` 等
**追加CSS:** `.weight-400`, `.italic`, `.is-link`, `.mono`

**デフォルトフォント:** Inter（weight: 300-700）、Roboto Mono（weight: 300-700）

## カラーシステム

Material Design 3トーナルパレットシステム。`@material/material-color-utilities` + `material-dynamic-colors` 使用。
マスターシードカラーからフルパレットを自動生成。個別キー（primary等）のカスタマイズ可能。

### セマンティックカラートークン（LkColor型）

| グループ | トークン |
|---------|---------|
| **Primary** | primary, onprimary, primarycontainer, onprimarycontainer, primaryfixed, primaryfixeddim, onprimaryfixed, onprimaryfixedvariant |
| **Secondary** | secondary, onsecondary, secondarycontainer, onsecondarycontainer, secondaryfixed, secondaryfixeddim, onsecondaryfixed, onsecondaryfixedvariant |
| **Tertiary** | tertiary, ontertiary, tertiarycontainer, ontertiarycontainer, tertiaryfixed, tertiaryfixeddim, ontertiaryfixed, ontertiaryfixedvariant |
| **Error** | error, onerror, errorcontainer, onerrorcontainer |
| **Success** | success, onsuccess, successcontainer, onsuccesscontainer |
| **Warning** | warning, onwarning, warningcontainer, onwarningcontainer |
| **Info** | info, oninfo, infocontainer, oninfocontainer |
| **Surface** | surface, onsurface, surfacevariant, onsurfacevariant, surfacedim, surfacebright, surfacecontainerlowest〜surfacecontainerhighest |
| **Neutral** | background, onbackground, outline, outlinevariant, shadow, scrim, inversesurface, inverseonsurface, inverseprimary |
| **Special** | transparent |

CSS変数: `var(--lk-primary)`, `var(--lk-onsurface)` 等。
ユーティリティ: `bg-{token}`（背景+テキスト色セット）、`color-{token}`（テキスト色のみ）。

### デフォルトパレット
```json
{
  "primary": "#035eff",
  "secondary": "#badcff",
  "tertiary": "#00ddfe",
  "neutral": "#000000",
  "neutralvariant": "#3f4f5b",
  "error": "#dd305c",
  "warning": "#feb600",
  "success": "#0cfecd",
  "info": "#175bfc"
}
```

## ダークモード

**1. 自動検知:** `@media (prefers-color-scheme: dark)` でOS設定に追従
**2. プログラム制御:** `ThemeProvider` の `colorMode` / `setColorMode`
**3. data属性:** `<html data-color-mode="dark">`
**4. 強制:** `<html data-force-dark-mode="true">`
**5. 部分的:** `<div data-dark-variant="true">` / `<div data-light-variant="true">`

ダークモード時、全`--lk-*`変数が`--dark__*_lkv`値に自動切替。

## レスポンシブデザイン

| 名称 | ブレークポイント |
|------|----------------|
| デスクトップ | 992px+ |
| タブレット | 768px - 991px |
| モバイル横 | 479px - 760px |
| モバイル縦 | 479px未満 |

大画面（1728px+）: font-size 17.28px、標準デスクトップ（1440px）: 16px。
相対単位ベースなので全コンポーネントが連動スケール。
