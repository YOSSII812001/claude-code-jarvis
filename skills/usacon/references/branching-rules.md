# ブランチ運用ルール・差異防止ルール

> 元のSKILL.mdの「ブランチ差異防止ルール（main/staging 乖離の再発防止）」セクション及び「worktree使用時の追加チェック」セクションから抽出

## ブランチ差異防止ルール（main/staging 乖離の再発防止）

> **過去に main と staging の差異が拡大し、マージ時に重大な問題が発生した。以下のルールを必ず守ること。**

### 重要原則（必須）
- **`feature` ブランチの作成元と PR の base は一致させる。**
- `main` 起点の feature を `staging` に直接 PR しない（逆も同様）。
- 依存機能が `main` のみに存在する場合は、以下を必ずセットで実施する：
  1. `feature -> main` PR を先にマージ
  2. 同日中に `main -> staging` 同期PR（または同期マージ）を作成
  3. 同期完了後に `staging` 向け作業を開始

### Issue 着手前チェック（必須）
```bash
git fetch origin
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git rev-parse origin/main
git rev-parse origin/staging
git log --oneline --left-right --cherry-pick origin/staging...origin/main | head -20
```

- `origin/main` と `origin/staging` の差分が issue 前提を壊す場合、**実装前に同期方針を決める**。
- 迷ったら「どの環境（Preview/Production）へ先に出すか」で base を決める。

### PR 作成ルール（差異発生の予防）
- Preview 検証目的の修正: `base=staging`
- 本番先行で `main` 依存の修正: `base=main`（ただし `main -> staging` 同期を必須化）
- **PR本文の先頭に次を明記する：**
  - `Base branch: <main|staging>`
  - `Reason: <なぜその base か>`
  - `Sync required: <yes|no>`（yes の場合は同期PR番号を追記）

### staging -> main マージの安全手順
- 必ず `~/.claude/skills/usacon/staging-to-main-merge.md` のチェックリストを実施すること
- 10コミット以上の場合はローカルでドライラン必須（staging-to-main-merge.md 参照）

## worktree使用時の追加チェック（必須）

worktree（`EnterWorktree` ツールまたは `git worktree add`）で作業する場合、
**worktree作成前にベースブランチを最新化すること。**

```bash
# worktree作成前の必須手順
git fetch origin
git checkout staging   # または main（ベースブランチに応じて）
git pull origin staging

# ベースが最新であることを確認してからworktree作成
git log --oneline -1
git rev-parse HEAD
git rev-parse origin/staging
# → HEAD と origin/staging が一致していることを確認
```

**背景:** Issue #910対応時、feature/issue-912ブランチにいた状態からmainに切り替えたところ
mainが106コミット遅れていた。メインリポジトリで作業したため `git pull` で最新化できたが、
もしworktreeで作業していた場合、古いmainベースのworktreeが作成され、
Privacy.tsx の最新変更との差異・上書きリスクがあった。

## PRベースブランチの選択

| シナリオ | ベースブランチ | 理由 |
|---------|--------------|------|
| 通常の機能開発・バグ修正 | `staging` | E2Eテスト必須 |
| 緊急のホットフィックス | `main` | 例外的に直接（要承認） |
| ドキュメントのみの変更 | `main` | E2E不要 |

## stagingブランチ運用ルール（必須）

> mainブランチへの直接マージは原則禁止。必ずstagingでE2Eテストを実施すること。

```bash
# 1. featureブランチで開発
git checkout -b feat/feature-name
# ... 開発 ...
git add . && git commit -m "feat: 機能追加"
git push origin feat/feature-name

# 2. PR作成（ベースブランチ: staging）
gh pr create --base staging --title "feat: 機能追加" --body "説明"

# 3. CodeRabbitレビュー → 修正 → stagingにマージ
gh pr checks <PR番号> --watch
gh pr merge <PR番号> --squash

# 4. デプロイ完了を待機（非ブロッキング方式）
# Bashツール run_in_background: true, timeout: 360000 で実行:
#   sleep 180 ; echo 'デプロイ待機完了'
# → 待機中にレビュー結果確認等の並行作業を実施

# 5. 【重要】プレビュー環境でE2Eテスト（Playwright MCP）
# preview.usacon-ai.com で機能の動作確認を必ず実施
# - 新機能が正常に動作するか
# - 既存機能にリグレッションがないか
# - エラーケースの処理が適切か

# 5.5. Issue起点の実装の場合、E2Eテスト成功後にIssueクローズ
# gh issue close <issue番号> --comment "E2Eテスト完了。preview環境で動作確認済み。PR #<PR番号>"

# 6. E2Eテスト成功後のみ、mainにマージ
git checkout staging && git pull origin staging
gh pr create --base main --head staging --title "Release: 機能名" --body "E2Eテスト完了"
gh pr checks <PR番号> --watch
gh pr merge --squash

# 7. 本番デプロイ完了を待機（非ブロッキング方式）
# Bashツール run_in_background: true, timeout: 360000 で実行:
#   sleep 300 ; echo 'デプロイ待機完了（本番）'
# → 待機中に並行作業を実施。完了後に usacon-ai.com で最終確認
```

**なぜstagingが必要か：**
- CodeRabbitは静的解析のみ、実際の動作は確認しない
- 本番環境でのバグ発見は影響が大きい
- プレビュー環境でのテストで問題を早期発見できる
