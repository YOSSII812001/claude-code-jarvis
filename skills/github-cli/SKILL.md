---
name: github-cli
description: |
  GitHub操作にはGitHub CLI（gh）を使用。MCPプラグインは使用しない。PR作成・マージ、Issue管理、レビュー確認など。/pr-flowコマンドで完全なPRフローを実行可能。
  トリガー: "github", "gh", "PR作成", "issue管理", "プルリクエスト", "レビュー確認"
---

# GitHub CLI ガイド

## 概要
GitHub操作にはGitHub CLI（`gh`コマンド）を使用。MCPプラグインは使用しない。

## インストール確認
```bash
gh --version

# 認証状態確認
gh auth status
```

## 基本コマンド

### PR操作
```bash
# PR一覧（オープン中）
gh pr list --state open

# PR作成
gh pr create --title "タイトル" --body "説明"

# PR詳細確認
gh pr view <PR番号>

# PRの変更ファイル一覧
gh pr diff <PR番号> --name-only

# PRチェック状態（CI/CD）
gh pr checks <PR番号>

# PRチェック完了まで待機（自動更新）
gh pr checks --watch

# PRマージ（squash + ブランチ削除）
gh pr merge --squash --delete-branch
```

### Issue操作
```bash
# Issue一覧
gh issue list

# Issue作成
gh issue create --title "タイトル" --body "説明"

# Issue詳細
gh issue view <Issue番号>
```

### Issue内の画像取得

GitHub Issueに添付された画像（`https://github.com/user-attachments/assets/...`）は認証が必要。
WebFetchやPlaywright（未ログイン）では404になるため、**認証付きCLIで取得する**。

```bash
# 1. Issue本文から画像URLを抽出
URLS=$(gh issue view <Issue番号> --json body -q '.body' | grep -oP 'https://github\.com/user-attachments/assets/[a-f0-9-]+')

# 2. 保存先ディレクトリを作成（Windowsパス — /tmp はRead toolで読めない）
mkdir -p "C:/Users/zooyo/tmp-issue-images"

# 3. 方法A: gh api（推奨・まずこちらを試す）
i=1
for url in $URLS; do
  gh api -H "Accept: application/octet-stream" "$url" > "C:/Users/zooyo/tmp-issue-images/issue-<Issue番号>-${i}.png"
  i=$((i+1))
done

# 4. サイズ検証（9バイト等の場合はリダイレクト応答なので方法Bへ）
ls -la C:/Users/zooyo/tmp-issue-images/

# 5. 方法B: curl + gh auth token（gh apiが9バイト等を返した場合のフォールバック）
TOKEN=$(gh auth token)
i=1
for url in $URLS; do
  curl -sL -H "Authorization: token $TOKEN" -H "Accept: application/octet-stream" \
    -o "C:/Users/zooyo/tmp-issue-images/issue-<Issue番号>-${i}.png" "$url"
  i=$((i+1))
done

# 6. Read toolで画像を確認（マルチモーダル表示）
# Read file_path="C:\Users\zooyo\tmp-issue-images\issue-<Issue番号>-1.png"

# 7. 確認後クリーンアップ
rm -rf C:/Users/zooyo/tmp-issue-images/
```

**注意事項:**
- `--repo` オプションでリポジトリ指定すれば `cd` 不要: `gh issue view 123 --repo owner/repo --json body`
- **必ずファイルサイズを検証する** — 数バイト〜数十バイトの場合はリダイレクト応答（方法Bで再取得）
- PR本文の画像も同じ手法で取得可能

### リポジトリ操作
```bash
# リポジトリ情報
gh repo view

# クローン
gh repo clone <owner>/<repo>
```

## /pr-flow カスタムコマンド

`/pr-flow` は llm ブランチでの開発完了後、mainブランチへマージするまでの完全フローを実行する。

### フロー概要

```
1. 事前確認（コンフリクトチェック）
      ↓
2. mainブランチから最新をpull
      ↓
3. 変更をコミット & プッシュ
      ↓
4. PR作成（まだない場合）
      ↓
5. CodeRabbitレビュー待機（gh pr checks --watch）
      ↓
6. 修正（必要な場合）
      ↓
7. ユーザー承認後マージ（gh pr merge --squash）
```

### コンフリクト予防の鉄則

| ルール | 説明 |
|--------|------|
| 作業開始前 | mainを最新にpull → llm新規作成 |
| PR作成後 | すぐにマージ（差分最小化） |
| mainブランチ | コード変更は絶対にしない |
| 重複チェック | オープンPRと修正ファイルの重複を確認 |

### PR作成前チェックスクリプト

```bash
# 全オープンPRの修正ファイルを確認
echo "=== オープン中のPR一覧 ==="
gh pr list --state open

# 各PRの修正ファイルを表示
for pr in $(gh pr list --state open --json number -q '.[].number'); do
  echo ""
  echo "=== PR #$pr の修正ファイル ==="
  gh pr diff $pr --name-only
done
```

### コンフリクト発生時の解決

```bash
# 頻繁にコンフリクトするファイル対策

# 1. ESLintログ等の自動生成ファイル → 自分のを採用
git checkout --ours <file>

# 2. 自分が触っていないファイル → mainのを採用
git checkout --theirs <file>

# 3. 両方に変更があるファイル → 手動マージ
# コンフリクトマーカーを編集

# 解決後
git add .
git commit -m "Merge branch 'main' into llm"
```

## ブランチ運用ルール

### 開発開始時（毎回実行）
```bash
git checkout main
git pull origin main
git checkout -b llm  # 毎回新規作成
```

### mainで作業してしまった場合（緊急対応）
```bash
git stash save "WIP: 作業内容"
git pull origin main
git checkout -b llm
git stash pop
# コンフリクト発生時は手動解決
```

## 注意事項

- **mainブランチへの直接コミット禁止**
- **PRマージ前に必ずユーザー承認を得る**
- **CodeRabbitの指摘は必ず修正**
- **古いllmブランチは使い回さない（毎回新規作成）**

## チェックリスト

- [ ] PR作成前にオープン中のPRと修正ファイルの重複を確認したか
- [ ] baseブランチを正しく指定したか（staging/main）
- [ ] CodeRabbitレビューのPRコメントを読んだか

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `gh auth` エラー | 認証トークン期限切れ | `gh auth login` で再認証 |
| PR作成時にbase指定忘れ | デフォルトブランチがmain | `--base staging` を明示 |
| `gh pr checks` がタイムアウト | CIが長い | `--watch` + バックグラウンド実行 |

## 関連スキル

- **usacon** — PR作成・マージの完全フロー（staging経由）
- **issue-flow** — Issue実装ワークフローでの `gh` コマンド活用
- **vercel-watch** — PRマージ後のデプロイ監視

## 参考
- GitHub CLI公式: https://cli.github.com/
- gh pr checks --watch: https://zenn.dev/hankei6km/articles/pull-request-with-github-cli

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-04 | 横断テンプレート適用（トリガー、チェックリスト、トラブルシューティング、関連スキル、改訂履歴追加） | スキル品質改善計画 |
| 2026-02-15 | 初版作成 | GitHub CLI操作の標準化 |
