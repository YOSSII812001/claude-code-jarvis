---
name: Supabase CLI Operations
description: |
  Supabaseプロジェクトの操作にSupabase CLIを使用。データベース、マイグレーション、Edge Functions、型生成など。
  トリガー: "supabase", "マイグレーション", "RLS", "Edge Functions", "型生成"
---

# Supabase CLI ガイド

## 概要
Supabaseプロジェクトの管理・操作にはSupabase CLIを使用してください。

## インストール確認
```bash
supabase --version
```

インストールされていない場合：
```bash
npm install -g supabase
```

## 基本コマンド

### プロジェクト初期化・リンク
```bash
# 新規プロジェクト初期化
supabase init

# 既存プロジェクトにリンク
supabase link --project-ref <project-id>

# ログイン
supabase login
```

### データベース操作
```bash
# マイグレーション作成
supabase migration new <migration_name>

# マイグレーション適用（ローカル）
supabase db reset

# マイグレーションをリモートにプッシュ
supabase db push

# 差分確認
supabase db diff
```

### Edge Functions
```bash
# 新規関数作成
supabase functions new <function_name>

# ローカルで実行
supabase functions serve

# デプロイ
supabase functions deploy <function_name>
```

### 型生成
```bash
# TypeScript型を生成
supabase gen types typescript --local > src/types/database.types.ts

# リモートDBから型生成
supabase gen types typescript --project-id <project-id> > src/types/database.types.ts
```

## Robbits プロジェクト設定
- Project Ref: `bpcpgettbblglikcoqux`
- リンクコマンド: `supabase link --project-ref bpcpgettbblglikcoqux`

## ベストプラクティス
1. 本番変更前に必ず `supabase db diff` で差分確認
2. マイグレーションファイルは必ずGit管理
3. RLSポリシーはマイグレーションに含める
4. Edge Functionsは環境変数で設定を分離

## マイグレーション作成時の注意事項（Issue #925教訓）

### remote_schemaマイグレーションの落とし穴

`supabase db remote commit` や `supabase db pull` 等で生成されるマイグレーションは、リモートDBの**現在の状態をそのまま反映**する。そのため、以下のリスクがある:

- **手動で追加したカラム**が、マイグレーション生成時のスナップショットに含まれず、意図せず削除される
- **手動で追加したRLSポリシー**が上書き・削除される
- **ALTER TABLE で追加した制約**（NOT NULL、DEFAULT値など）が消失する

**対策（必須）:**
```bash
# 1. マイグレーション生成後、必ず差分を確認
git diff supabase/migrations/

# 2. DROP COLUMN, DROP POLICY, ALTER COLUMN が含まれていないか重点チェック
grep -n "DROP\|ALTER.*DROP\|REVOKE" supabase/migrations/<新しいマイグレーションファイル>

# 3. 意図しない削除があれば、該当行を手動で除去するか、マイグレーションを修正
```

**重要:** 自動生成されたマイグレーションを**無条件で適用しない**こと。必ず内容を精査してから `supabase db push` を実行する。

### 空文字列 vs NULL（PostgreSQL）

PostgreSQLでは空文字列`''`とNULLは明確に異なる値として扱われる:

| 値 | `IS NULL` | `= ''` | `COALESCE(col, 'default')` |
|----|-----------|--------|---------------------------|
| `NULL` | true | false | `'default'` |
| `''` | false | true | `''` |

**問題:** フロントエンドのフォームは未入力フィールドを空文字列`''`で送信しがち。NULL許容カラムに空文字列が保存されると、`IS NULL`チェックやCOALESCEが期待通り動作しない。

**対策:**
- フロントエンド側で、DB保存前に空文字列→null変換を行う
- 例: `const value = input.trim() === '' ? null : input.trim()`
- NULL許容カラムには意味的に`null`を入れ、空文字列は避ける

## チェックリスト

- [ ] マイグレーション適用前に `supabase db diff` で差分を確認したか
- [ ] 自動生成マイグレーションにDROP/ALTER DROPが含まれていないか確認したか
- [ ] RLSポリシーがマイグレーションに含まれているか
- [ ] 新テーブルのTIMESTAMPカラムは `TIMESTAMPTZ` を使用しているか
- [ ] 空文字列とNULLの扱いを意識しているか

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `supabase login` 失敗 | アクセストークン期限切れ | `supabase login` で再認証 |
| `supabase db push` エラー | マイグレーション競合 | `supabase db diff` で差分確認後、手動修正 |
| `supabase link` 失敗 | project-ref間違い | `bpcpgettbblglikcoqux` を確認 |
| 型生成で型が古い | ローカルDBが未更新 | `supabase db reset` 後に `gen types` |
| Edge Functions デプロイ失敗 | Denoバージョン不一致 | CLIを最新に更新 |

## 関連スキル

- **usacon** — Supabase統合の実プロジェクト
- **stripe-cli** — billing連携
- **usacon-account-mgmt** — Supabase Auth Admin API操作

## 参考
- 公式ドキュメント: https://supabase.com/docs/guides/cli

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-04 | 横断テンプレート適用（トリガー、チェックリスト、トラブルシューティング、関連スキル、改訂履歴追加） | スキル品質改善計画 |
| 2026-02-15 | Issue #925教訓（remote_schema落とし穴、空文字列vsNULL）追加 | 実運用で発見された問題の知見化 |
| 2026-02-10 | 初版作成 | Supabase CLI操作の標準化 |
