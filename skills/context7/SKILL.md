---
name: Context7 Documentation Lookup
description: |
  ライブラリやフレームワークのドキュメントを検索する際にContext7プラグインを使用。
  トリガー: "context7", "ドキュメント検索", "ライブラリドキュメント", "最新ドキュメント", "API仕様確認"
---

# Context7 ドキュメント検索

## 概要
ライブラリやフレームワークの最新ドキュメントを検索する際は、Context7プラグインを使用してください。
古い情報やハルシネーションを防ぎ、正確なAPI仕様・使用方法を取得できます。

## 使用方法

### プラグインコマンド
```
/context7
```

### 検索の流れ
1. まず `resolve-library-id` でライブラリIDを取得
2. 次に `get-library-docs` でドキュメントを取得

### 完全なフロー例

#### ステップ1: ライブラリIDの解決
```
mcp__plugin_context7_context7__resolve-library-id
  libraryName: "react"
```

レスポンス例:
```json
{
  "libraryId": "/facebook/react",
  "name": "React",
  "description": "A JavaScript library for building user interfaces",
  "codeSnippetCount": 1200,
  "trustScore": 10
}
```

#### ステップ2: ドキュメントの取得
```
mcp__plugin_context7_context7__get-library-docs
  context7CompatibleLibraryID: "/facebook/react"
  topic: "hooks"
  tokens: 5000
```

#### ステップ3: 取得したドキュメントの活用
- バージョン情報を確認し、最新であることを検証
- 必要に応じて `tokens` を増やして詳細を取得
- `topic` を変更して別の機能のドキュメントを取得

### 例：Supabase のRLS設定を調べる
```
# ライブラリIDを解決
mcp__plugin_context7_context7__resolve-library-id
  libraryName: "supabase"

# RLSに関するドキュメント取得
mcp__plugin_context7_context7__get-library-docs
  context7CompatibleLibraryID: "/supabase/supabase"
  topic: "row level security"
  tokens: 8000
```

### 例：Next.js App Router のドキュメントを取得
```
# ライブラリIDを解決
mcp__plugin_context7_context7__resolve-library-id
  libraryName: "next.js"

# App Routerに関するドキュメント取得
mcp__plugin_context7_context7__get-library-docs
  context7CompatibleLibraryID: "/vercel/next.js"
  topic: "app router"
  tokens: 10000
```

## よく使うライブラリIDテーブル

| ライブラリ | Context7 ID | 用途 |
|-----------|------------|------|
| React | /facebook/react | フロントエンド |
| Next.js | /vercel/next.js | フレームワーク |
| Supabase | /supabase/supabase | データベース |
| Tailwind CSS | /tailwindlabs/tailwindcss | スタイリング |
| Playwright | /microsoft/playwright | E2Eテスト |
| Stripe | /stripe/stripe-node | 決済 |
| shadcn/ui | /shadcn-ui/ui | UIコンポーネント |
| TypeScript | /microsoft/typescript | 型システム |
| Node.js | /nodejs/node | サーバーサイド |
| Prisma | /prisma/prisma | ORM |

> **注意:** IDはresolve-library-idの結果に基づく参考値です。正確なIDは必ず `resolve-library-id` で確認してください。

## パラメータガイド

### tokens パラメータ
| 用途 | 推奨値 | 説明 |
|------|--------|------|
| 概要確認 | 3000 | ライブラリの基本的な使い方 |
| 標準的な調査 | 5000（デフォルト） | 一般的なAPI仕様の確認 |
| 詳細な調査 | 8000-10000 | 複雑な機能や設定の詳細 |
| 包括的な調査 | 15000-20000 | 大規模な機能の全体像把握 |

### topic パラメータ
- 具体的なキーワードを指定すると関連部分に絞り込み可能
- 例: `"hooks"`, `"routing"`, `"authentication"`, `"row level security"`
- 指定しない場合はライブラリの概要的なドキュメントが返される

## 使用時のチェックリスト

- [ ] `resolve-library-id` でIDを取得したか
- [ ] `topic` パラメータで関連部分に絞り込んだか
- [ ] 取得したドキュメントのバージョンが最新か確認したか
- [ ] `tokens` パラメータが用途に適した値か確認したか
- [ ] 複数トピックが必要な場合、個別に `get-library-docs` を呼び出したか

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| ライブラリIDが見つからない | `resolve-library-id` でまず検索。正式名称やnpmパッケージ名で再試行 |
| ドキュメントが少ない/古い | `tokens` パラメータを10000に増やす。`topic` を具体的に指定 |
| タイムアウトする | Context7サーバーの一時的な問題。数分後にリトライ |
| 期待と異なるドキュメントが返る | `topic` をより具体的に変更。例: `"hooks"` → `"useEffect cleanup"` |
| バージョン固有の情報が必要 | ライブラリIDにバージョンを付与: `/vercel/next.js/v14.3.0-canary.87` |

## 注意事項
- 古い情報やハルシネーションを避けるため、必ずContext7で最新ドキュメントを確認
- tokenパラメータで取得量を調整（デフォルト5000）
- topicを指定すると関連部分に絞り込み可能
- 同一セッションで同じライブラリを複数回検索する場合、IDの再解決は不要

## 関連スキル

- **skill-improve** — スキル改善時のドキュメント確認に使用。改善対象の技術スタックのドキュメントをContext7で取得し、正確性を担保
- **usacon** — usaconプロジェクトのライブラリドキュメント参照。React、Next.js、Supabase等の最新API仕様確認に活用

## 改訂履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-07-18 | 1.0 | 初版作成。基本的な使用方法を記載 |
| 2026-03-04 | 2.0 | 大幅改善: MCP呼び出し形式の完全フロー例追加、ライブラリIDテーブル追加、パラメータガイド追加、トラブルシューティング追加、チェックリスト追加、関連スキル追加 |
