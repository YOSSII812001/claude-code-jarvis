<!-- 抽出元: SKILL.md - コンポーネント一覧と Props セクション全体 -->

# LiftKit コンポーネント一覧と Props API

## Button
```typescript
interface LkButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  label?: string;                          // デフォルト: "Button"
  variant?: "fill" | "outline" | "text";   // デフォルト: "fill"
  color?: LkColorWithOnToken;              // デフォルト: "primary"
  size?: "sm" | "md" | "lg";              // デフォルト: "md"
  material?: string;
  startIcon?: IconName;                    // Lucideアイコン名
  endIcon?: IconName;
  opticIconShift?: boolean;                // デフォルト: true
  modifiers?: string;                      // 追加CSSクラス
  stateLayerOverride?: LkStateLayerProps;
}
```
```tsx
<Button label="送信" variant="fill" size="md" color="primary" startIcon="send" />
```

## Card
```typescript
interface LkCardProps extends React.HTMLAttributes<HTMLDivElement> {
  scaleFactor?: LkFontClass | "none";                    // デフォルト: "body"
  variant?: "fill" | "outline" | "transparent";          // デフォルト: "fill"
  material?: "flat" | "glass";                           // デフォルト: "flat"
  materialProps?: LkMatProps;
  opticalCorrection?: "top"|"left"|"right"|"bottom"|"x"|"y"|"all"|"none"; // デフォルト: "none"
  isClickable?: boolean;
  bgColor?: LkColorWithOnToken | "transparent";          // デフォルト: "surface"
  isScrollable?: boolean;                                // デフォルト: false
}
```
```tsx
<Card variant="outline" material="glass" opticalCorrection="top" isClickable>
  <Heading tag="h2">タイトル</Heading>
  <Text>コンテンツ</Text>
</Card>
```

## Heading
```typescript
interface LkHeadingProps extends React.HTMLAttributes<HTMLHeadingElement> {
  tag?: "h1" | "h2" | "h3" | "h4" | "h5" | "h6";  // デフォルト: "h2"
  fontClass?: string;       // デフォルト: "display2-bold"
  fontColor?: string;
}
```

## Text
```typescript
interface LkTextProps extends React.HTMLAttributes<HTMLElement> {
  fontClass?: LkFontClass;
  content?: string;
  color?: LkColor;
  tag?: LkSemanticTag;      // デフォルト: "div"
}
```

## Container
```typescript
interface LkContainerProps extends React.HTMLAttributes<HTMLDivElement> {
  maxWidth?: "xs" | "sm" | "md" | "lg" | "xl" | "none" | "auto";  // デフォルト: "md"
}
```

## Grid
```typescript
interface LkGridProps extends React.HTMLAttributes<HTMLDivElement> {
  columns?: number;          // デフォルト: 2
  gap?: LkSizeUnit;         // デフォルト: "md"
  autoResponsive?: boolean;  // デフォルト: false
}
```

## Column
```typescript
interface LkColumnProps extends React.HTMLAttributes<HTMLDivElement> {
  alignItems?: "start" | "center" | "end" | "stretch";       // デフォルト: "stretch"
  justifyContent?: "start" | "center" | "end" | "space-between" | "space-around"; // デフォルト: "start"
  gap?: LkSizeUnit | "none";
  wrapChildren?: boolean;
  defaultChildBehavior?: "auto-grow" | "auto-shrink" | "ignoreFlexRules" | "ignoreIntrinsicSize";
}
```

## Row
```typescript
interface LkRowProps extends React.HTMLAttributes<HTMLDivElement> {
  alignItems?: "start" | "center" | "end" | "stretch";       // デフォルト: "start"
  justifyContent?: "start" | "center" | "end" | "space-between" | "space-around"; // デフォルト: "start"
  gap?: LkSizeUnit;
  wrapChildren?: boolean;
  defaultChildBehavior?: "auto-grow" | "auto-shrink" | "ignoreFlexRules" | "ignoreIntrinsicSize";
}
```

## Section
```typescript
interface LkSectionProps extends React.HTMLAttributes<HTMLElement> {
  padding?: "xs" | "sm" | "md" | "lg" | "xl" | "none";
  container?: React.ReactNode;
  px?: SpacingSize; py?: SpacingSize;
  pt?: SpacingSize; pb?: SpacingSize;
  pl?: SpacingSize; pr?: SpacingSize;
}
```

## Badge
```typescript
interface LkBadgeProps extends React.HTMLAttributes<HTMLDivElement> {
  icon?: IconName;              // デフォルト: "roller-coaster"
  color?: LkColorWithOnToken;   // デフォルト: "surface"
  scale?: "md" | "lg";          // デフォルト: "md"
  iconStrokeWidth?: number;      // デフォルト: 1.5
  scrim?: boolean;               // デフォルト: false
}
```

## Icon
```typescript
interface LkIconProps extends React.HTMLAttributes<HTMLElement> {
  name?: IconName;                        // デフォルト: "roller-coaster"
  fontClass?: LkFontClass;
  color?: LkColor | "currentColor";      // デフォルト: "onsurface"
  display?: "block" | "inline-block" | "inline";
  strokeWidth?: number;                   // デフォルト: 2
  opticShift?: boolean;                   // デフォルト: false
}
```
アイコンライブラリ: `lucide-react`（DynamicIcon）。`width="1em" height="1em"` でレンダリング。

## Icon Button
```typescript
interface LkIconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  icon: IconName;                          // デフォルト: "roller-coaster"
  variant?: "fill" | "outline" | "text";   // デフォルト: "fill"
  color?: LkColorWithOnToken;              // デフォルト: "primary"
  size?: "xs" | "sm" | "md" | "lg" | "xl"; // デフォルト: "md"
  fontClass?: LkFontClass;                 // デフォルト: "body"
}
```

## Image
```typescript
interface LkImageProps extends React.ImgHTMLAttributes<HTMLImageElement> {
  aspect?: LkAspectRatio;      // デフォルト: "auto"
  borderRadius?: LkSizeUnit | "none" | "zero";
  objectFit?: React.CSSProperties["objectFit"]; // デフォルト: "fill"
  width?: LkSizeUnit | "auto";  // デフォルト: "auto"
  height?: LkSizeUnit | "auto"; // デフォルト: "auto"
}
// LkAspectRatio = "auto"|"1/1"|"2.39/1"|"2/1"|"16/9"|"3/2"|"4/3"|"5/4"|"1/2.39"|"1/2"|"9/16"|"4/5"
```

## Navbar
```typescript
interface LkNavBarProps extends React.HTMLAttributes<HTMLDivElement> {
  material?: LkMaterial;         // デフォルト: "flat"
  navButtons?: React.ReactNode;
  navDropdowns?: React.ReactNode;
  iconButtons?: React.ReactNode;
  ctaButtons?: React.ReactNode;
}
```
デスクトップ/モバイルレイアウトを自動切替。モバイルはハンバーガーメニュー付き。

## Tabs
```typescript
interface LkTabsProps extends React.HTMLAttributes<HTMLDivElement> {
  tabLinks: string[];
  children: React.ReactNode[];
  scrollableContent?: boolean;
  onActiveTabChange?: (index: number) => void;
}
```

## Dropdown（複合コンポーネント）
```tsx
<Dropdown>
  <DropdownTrigger>{/* クリック要素 */}</DropdownTrigger>
  <DropdownMenu cardProps={cardProps}>{/* メニュー内容 */}</DropdownMenu>
</Dropdown>
```
ポータルレンダリング、ビューポート象限ベース配置、シングルトンレジストリ（同時1つ）。

## Select（複合コンポーネント）
```typescript
interface SelectProps {
  label?: string;
  labelPosition?: "default" | "on-input";
  helpText?: string;
  placeholderText?: string;
  options: { label: string; value: string }[];
  value: string;
  onChange: (event: React.ChangeEvent<HTMLSelectElement>) => void;
  name?: string;
  children: React.ReactNode;
}
```
```tsx
<Select label="選択" options={options} value={val} onChange={handleChange}>
  <SelectTrigger />
  <SelectMenu>
    <SelectOption value="a">オプションA</SelectOption>
  </SelectMenu>
</Select>
```
隠しネイティブ`<select>`でフォーム互換。キーボードナビ対応。

## Text Input
```typescript
interface LkTextInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  labelPosition?: "default" | "on-input";  // デフォルト: "default"
  helpText?: string;
  placeholder?: string;                    // デフォルト: "Placeholder"
  name?: string;                           // デフォルト: "Label"
  endIcon?: IconName;                      // デフォルト: "search"
  labelBackgroundColor?: LkColor;
}
```

## Snackbar
```typescript
interface LkSnackbarProps extends React.HTMLAttributes<HTMLDivElement> {
  globalColor?: LkColorWithOnToken;
  message?: string;                // デフォルト: "Notification text goes here."
  children?: React.ReactNode;      // Badge, Button, Icon, IconButton, Text のみ許可
  cardProps?: LkCardProps;
}
```

## Sticker
```typescript
interface LkStickerProps extends React.HTMLAttributes<HTMLDivElement> {
  fontClass?: LkFontClass;        // デフォルト: "label"
  bgColor?: LkColor;              // デフォルト: "primarycontainer"
}
```

## Switch
```typescript
interface LkSwitchProps {
  onClick?: (switchIsOn?: boolean) => void;
  offColor?: LkColorWithOnToken;   // デフォルト: "surfacevariant"
  onColor?: LkColorWithOnToken;    // デフォルト: "primary"
  value?: boolean;
}
```

## MenuItem
```typescript
interface LkMenuItemProps extends React.HTMLAttributes<HTMLDivElement> {
  startIcon?: LkIconProps;
  endIcon?: LkIconProps;
  fontClass?: LkFontClass;        // デフォルト: "body"
  title?: string;
}
```

## Material Layer
```typescript
interface LkMaterialLayerProps extends React.HTMLAttributes<HTMLDivElement> {
  zIndex?: number;                  // デフォルト: 0
  type?: "flat" | "glass" | "debug";
  materialProps?: LkMatProps;
}
```

## State Layer
```typescript
interface LkStateLayerProps {
  bgColor?: LkColor | "currentColor";  // デフォルト: "currentColor"
  forcedState?: "hover" | "active" | "focus";
}
```
hover: 10% opacity, active: 20% opacity で自動適用。

## Theme（ThemeProvider）
```typescript
interface ThemeContextType {
  theme: { light: ThemeColors; dark: ThemeColors };
  updateTheme: (palette: PaletteState) => Promise<void>;
  updateThemeFromMaster: (hexCode: string, setPalette: ...) => Promise<void>;
  palette: PaletteState;
  setPalette: React.Dispatch<React.SetStateAction<PaletteState>>;
  colorMode: "light" | "dark";
  setColorMode: React.Dispatch<React.SetStateAction<"light" | "dark">>;
  navIsOpen: boolean;
  setNavIsOpen: React.Dispatch<React.SetStateAction<boolean>>;
}
```
`useTheme()` フックでアクセス。アプリをラップして使用。

## Theme Controller
ライブテーマ編集パネル。マスター、ブランド（primary/secondary/tertiary）、セマンティック（error/warning/success/info）、レイアウト（neutral/neutralvariant）パレットのカラーピッカー。"copy config" ボタンでパレット状態をコピー。

## ユーティリティ関数

### propsToDataAttrs
コンポーネントpropsをCSSターゲット用data属性に変換:
```typescript
propsToDataAttrs({ variant: "fill", color: "primary" }, "button")
// → { "data-lk-button-variant": "fill", "data-lk-button-color": "primary" }
```

### getOnToken
補色トークンを返す:
```typescript
getOnToken("primary")              // → "onprimary"
getOnToken("surfacecontainerhigh") // → "onsurface"
getOnToken("onprimary")            // → "primary"（逆引き）
```

## ファイル構造

```
registry/
  nextjs/
    components/        -- Reactコンポーネント（各フォルダにCSS + index.tsx）
      badge/ button/ card/ column/ container/ dropdown/ grid/
      heading/ icon/ icon-button/ image/ material-layer/ menu-item/
      navbar/ row/ section/ select/ snackbar/ state-layer/ sticker/
      switch/ tab-content/ tab-link/ tab-menu/ tabs/ text/ text-input/
      theme/ theme-controller/ placeholder-block/
    lib/
      componentUtils.ts
      utilities.ts     -- propsToDataAttrs
  universal/
    lib/
      colorUtils.ts    -- getOnToken
      css/             -- 全ユーティリティCSS + index.css
      types/           -- 型定義（lk-color, lk-material, lk-shape, lk-typography, lk-units, lk-utility）
```
