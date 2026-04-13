<!-- 抽出元: SKILL.md - ユーティリティクラス（38カテゴリ）、UIパターンガイド、注意事項・トラブルシューティング、UI品質チェックリスト セクション -->

# LiftKit ユーティリティクラスとUIガイド

## ユーティリティクラス（38カテゴリ）

Tailwindと同じクラス名を使用。Tailwind本体は不要。未使用CSSはビルド時に自動tree-shake。

| カテゴリ | 用途 | クラス例 |
|---------|------|---------|
| **レイアウト** | display, position, overflow, z-index | `display-flex`, `position-relative`, `z-10` |
| **Flex** | flexboxes, align-items, align-self, justify-content, justify-items | `flex-h`, `align-items-center`, `justify-between` |
| **グリッド** | column-span, gaps | `gap-md`, `gap-lg` |
| **サイズ** | width, height, scale, aspect-ratios | `w-full`, `h-auto`, `aspect-16/9` |
| **スペーシング** | margins, padding | `p-md`, `px-lg`, `mt-sm`, `mb-xl` |
| **外観** | background-color, borders, border-color, border-radius, border-style, shadows, opacity, scrim | `bg-primary`, `shadow-lg`, `br-md`, `opacity-50` |
| **タイポグラフィ** | typography, text-alignment, text-color, text-columns, whitespace | `body`, `display1-bold`, `text-center`, `color-primary` |
| **インタラクション** | cursor, pointer-events | `cursor-pointer`, `pointer-events-none` |
| **マテリアル** | material, liftkitvars | CSS変数・マテリアルスタイル |
| **その他** | breaks, code, inputs, liftkit-core | リセット・正規化 |

## UI品質チェックリスト

LiftKitで実装した後、以下7項目を確認する:

1. **情報階層** - 主要アクションが視覚的に支配的か。3秒でページ構造を把握できるか
2. **スペーシング** - 体系的な間隔（ad-hocなpx指定なし）。セクション間のリズムが一貫しているか
3. **タイポグラフィ一貫性** - Heading/body/labelスケールが整合。ウェイトと行高が速読を支援しているか
4. **コントラスト・可読性** - テキスト/背景のコントラストが十分。disabled/mutedスタイルも読めるか
5. **ステート遷移・フィードバック** - hover/focus/active/disabled/loadingが可視。タイミングがレスポンシブか
6. **レスポンシブ** - 主要フローが各ブレークポイントで動作。overflow・clipping・タッチターゲット問題なし
7. **ユーザビリティ** - フォーム・テーブル・ナビ・モーダルの摩擦が最小。キーボード・フォーカスが予測可能か

## UIパターンガイド

### Form
- **Apply:** ラベル・ヘルパーテキスト・エラーテキストの階層を統一。フィールド間隔と垂直リズムを標準化。focus/error/disabled/loadingステートを明示。プライマリsubmitを視覚的に優先
- **Avoid:** フィールド高さの不統一、プレースホルダーのみのラベル、隠れたバリデーション

### Card
- **Apply:** タイトル/本文/メタ/アクションゾーンを明確化。内部スペーシングを統一スケールに。構造を伝える場合のみelevation/borderを変更
- **Avoid:** 複数の競合するアクセント、理由のないカード高さの不統一

### Navigation
- **Apply:** active状態をhover/focusと明確に区別。高頻度アクションの配置を予測可能に。キーボードフォーカストラバーサルを明確に
- **Avoid:** 曖昧なアクティブ位置、操作を遅延させる過度なアニメーション

### Table
- **Apply:** ヘッダー階層とカラム配置を厳密に。行hover/focus/actionアフォーダンスを可視化。狭いビューポートでの水平動作を検証
- **Avoid:** 精密なホバーでのみ表示されるアクション、モバイル対応の不備

### Modal
- **Apply:** タイトル・結果の説明・明示的なprimary/secondaryアクション。フォーカストラップと閉じ時のフォーカス復元。ESCキーパスを提供
- **Avoid:** primaryと破壊的アクションの視覚的類似、重要コンテキストを隠すモーダル

## 注意事項・トラブルシューティング

| 問題 | 解決策 |
|------|--------|
| React 19の警告 | `Use --force` を選択して続行 |
| Tailwindとの競合 | Tailwind本体は不要。config fileのみ必要（shadcnレジストリ用） |
| 未使用CSS | ビルド時に自動削除（tree-shaking） |
| `direnv: error` | テンプレートclone時に出るが無視してOK |
| 依存コンポーネント | 自動インストールされる（例: Badge → Icon） |
| Buttonパディング制御 | アイコン有無でパディングが自動調整。props制御は現状不可 |
| calc()デバッグ | 加算/減算は同一単位必須、乗算は片方unitless、除算は右辺unitless |
