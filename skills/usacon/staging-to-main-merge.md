# staging → main マージ安全ガイド

## 概要

stagingからmainへのマージは本番環境に直接影響するため、特別な注意が必要。
このスキルは過去のインシデントから得た教訓をもとに、安全なマージ手順を定義する。

---

## インシデント履歴

### 2026-02-06: squashマージによる関数重複（PR #548 → #550で修正）

**発生状況:**
- PR #548（staging → main、26コミット分）を `--squash` でマージ
- `ChatAssistant.tsx` 内の `handleDeleteClick` 等3関数が**2回宣言**される状態でマージされた
- 本番Vercelビルドが即座にエラー（`The symbol "handleDeleteClick" has already been declared`）

**原因:**
- 複数のPR（#532, #545等）が同一ファイル `ChatAssistant.tsx` を修正していた
- squashマージ時にコードが重複挿入された

**影響:**
- 本番ビルド失敗（19秒でエラー終了）
- 緊急ホットフィックスPR #550 で38行の重複を削除

**教訓:**
- squashマージは多数のコミットを1つにまとめるため、衝突解決が不完全になりやすい
- 特に同一ファイルを複数PRで修正している場合にリスクが高い

---

## staging → main マージ前チェックリスト

### 1. 重複修正ファイルの確認（必須）

```bash
# stagingに含まれる全変更ファイルを一覧
git diff origin/main..origin/staging --name-only

# 同一ファイルを修正している複数PRがないか確認
# 特に注意: .tsx, .ts, .js の大きなコンポーネントファイル
```

**要注意ファイル（過去に重複が発生したもの）:**
- `frontend/src/components/chat/ChatAssistant.tsx`
- その他、複数PRで頻繁に修正される大きなファイル

### 2. ローカルビルド確認（必須）

```bash
# mainブランチにstagingをマージした状態でビルド確認
git checkout main
git pull origin main
git merge origin/staging --no-commit --no-ff

# ビルドテスト
cd frontend && npm run build

# 問題なければコミット、問題あれば修正
git merge --abort  # 問題がある場合はリセット
```

### 3. マージ方式の選択

| 方式 | コマンド | リスク | 推奨場面 |
|------|---------|--------|---------|
| **squash** | `gh pr merge --squash` | ⚠️ コード重複リスクあり | コミット数が少ない場合（~5件） |
| **merge commit** | `gh pr merge --merge` | ✅ 安全（個別コミット保持） | コミット数が多い場合（5件~） |
| **rebase** | `gh pr merge --rebase` | ⚠️ コンフリクト時に複雑 | 線形履歴が必要な場合 |

**推奨:** staging → main は `--merge`（マージコミット）を使用する。
squashは個別のfeature → staging PRで行い、staging → main では履歴を保持する。

### 4. 関連Issueのクローズ確認（必須）— Issue #1020閉じ忘れ教訓

> **staging→mainマージ前に、関連する全Issueが閉じられていることを確認する。**
> メインIssueだけでなく、子Issue・派生Issue・残作業Issueの閉じ忘れが発生しやすい。

```bash
# マージ対象の機能に関連するキーワードで検索
gh issue list --state open --search "<機能名キーワード>"

# PRタイトル・本文に含まれるIssue番号の派生Issueも検索
gh issue list --state open --search "<親Issue番号>"

# 0件になることを確認してからマージへ進む
```

**閉じ忘れやすいパターン:**
- 「残作業」「Phase 2」「追加対応」として切り出した子Issue
- PR本文で `Closes #XXX` を付けなかったIssue
- 複数PRにまたがる機能の一部Issueだけ閉じて他を忘れる

### 5. マージ後の即座確認（必須）

```bash
# マージ直後にVercelデプロイ状況を確認（1分以内）
npx vercel ls digital-management-consulting-app --yes 2>&1 | head -5

# Productionデプロイのステータスが "● Ready" になるまで監視
# "● Error" の場合は即座にホットフィックス対応
```

### 6. ビルドエラー時の緊急対応

```bash
# 1. エラーログ確認
npx vercel inspect <error-deployment-url> --logs 2>&1

# 2. ホットフィックスブランチ作成（mainから直接）
git checkout main && git pull origin main
git checkout -b fix/hotfix-description

# 3. 修正・コミット・PR作成（mainベース）
git add <files> && git commit -m "fix: 説明"
git push origin fix/hotfix-description
gh pr create --base main --title "fix: ビルドエラー修正" --body "緊急修正"

# 4. チェック通過後、即マージ
gh pr checks <PR番号> --watch
gh pr merge <PR番号> --squash
```

---

## 予防策

### 大規模マージ前のドライラン

staging → main のPRが**10コミット以上**の場合、必ずローカルでマージ＆ビルドを事前実行する。

```bash
# ドライランスクリプト
git fetch origin
git checkout -B merge-test origin/main
git merge origin/staging --no-ff
cd frontend && npm run build
echo "ビルド成功: マージ可能"
git checkout main
git branch -D merge-test
```

### CI/CDでのビルドチェック強化

Vercelのプレビュービルドが staging → main PRでも実行されることを確認する。
PR作成時のVercelチェックが `pass` であればビルドは安全。

### コミット頻度の最適化

staging → main のマージは、溜めすぎずに定期的に行う（理想: 5-10コミット程度）。
コミット数が多いほど重複・衝突リスクが増大する。
