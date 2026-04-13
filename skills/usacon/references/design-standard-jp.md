# ウサコン日本語UIデザイン基準

> Issue #1764 で確立。全フロントエンドUI変更時に必須参照。

## スキル連携

**必須スキル**: `awesome-design-md-jp`（23社の日本企業デザインシステム参照）

フロントエンドUI変更を含むIssue実装時は、awesome-design-md-jpスキルを読み込み、以下の参照デザインシステムに準拠した実装を行うこと。

## 参照デザインシステム（ウサコン標準5社）

| 参照元 | 適用要素 | 適用しない要素 |
|--------|---------|---------------|
| **SmartHR** | 情報階層の明確化、セマンティックカラー、ソフトなフォーカスリング（`boxShadow: 0 0 0 3px rgba(94, 129, 172, 0.15)`） | warm gray（Nord維持） |
| **freee** | 数値表示の視認性、テーブルの可読性（ストライプ行、ヘッダー letter-spacing） | — |
| **Sansan** | プロフェッショナルな Button・Card スタイリング | — |
| **サイボウズ** | 情報密度と可読性のバランス、スペーシングスケール（4px/8pxベース） | — |
| **LINE** | 日本語タイポグラフィ（禁則処理、palt/kern、フォントスタック最適化） | — |

## 日本語タイポグラフィ基盤（必須準拠）

### フォントスタック
```
Inter, "Noto Sans JP", "Hiragino Sans", "Hiragino Kaku Gothic ProN", Meiryo, sans-serif
```

### 禁則処理・OpenType
```css
overflow-wrap: anywhere;
line-break: strict;          /* 日本語禁則処理 */
font-feature-settings: "palt" 1, "kern" 1;
font-kerning: normal;
```

### タイポグラフィスケール
- **見出し（h1-h6）**: line-height: 1.3-1.4
- **本文（body1/body2）**: letter-spacing: 0.02em-0.04em
- **日本語UIでは `textTransform: 'uppercase'` と `letterSpacing: '0.05em'` を使用しない**

## コンポーネントスタイリング基準

### MuiButton
- サイズバリエーション（small/medium/large）の余白・フォントサイズ統一
- hover時の transform を控えめに（SmartHR的に静的）

### MuiCard
- hover: `transform: translateY(-1px)`（控えめ）
- 情報表示カードは shadow 変化のみ

### MuiTableCell
- セル余白の拡大
- ヘッダー: letter-spacing 0.02em
- ストライプ行（奇数行に薄い背景）

### MuiTextField
- フォーカスリング: SmartHR風ソフト shadow

## テーマ間の一貫性

- **NordLight / Cyberpunk 両テーマで同等のタイポグラフィ・禁則処理を適用すること**
- テーマ固有のカラーパレットは変更しない
- CSS変数ベースでテーマトークンを管理

## アクセシビリティ

- WCAG AA コントラスト比（4.5:1）を全カラー変更で維持
- `prefers-reduced-motion` 対応を考慮
- Lighthouse Accessibility スコア 90+ 維持

## 実装時のチェックポイント

1. [ ] 新規UIコンポーネントが上記フォントスタック・禁則処理を継承しているか
2. [ ] `textTransform: 'uppercase'` や英語向け letterSpacing を使用していないか
3. [ ] テーマトークン（CSS変数 or MUIテーマ）を使用し、ハードコードカラーを避けているか
4. [ ] NordLight / Cyberpunk 両テーマで表示確認しているか
5. [ ] 日本語テキストの折り返し・禁則処理が正常か

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-10 | Issue #1764 の成果を基に初版作成 |
