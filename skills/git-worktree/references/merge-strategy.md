<!-- 抽出元: SKILL.md のセクション「Step 7 への補足: worktree からのマージ戦略」「Step 8（staging 経由の場合）」「マージ競合の解決」 -->

# git worktree マージ戦略

## 順次マージ戦略（推奨）

マージ先は**ベースブランチ**（`$baseBranch`）。main に直接マージしない。

```powershell
# === 順次マージ戦略（推奨） ===
# メインリポジトリのベースブランチで実行

$baseBranch = "staging"  # プロジェクトに合わせて変更
Set-Location "C:\project\my-app"
git checkout $baseBranch
git pull origin $baseBranch

# 1. DB層を最初にマージ（最も基盤）
git merge feature/db --no-ff -m "Merge feature/db: DB層実装"

# 2. 型チェック
# npx tsc --noEmit（TypeScriptの場合）

# 3. API層をマージ
git merge feature/api --no-ff -m "Merge feature/api: API実装"

# 4. 型チェック + テスト
# npx tsc --noEmit; npm test

# 5. UI層を最後にマージ
git merge feature/ui --no-ff -m "Merge feature/ui: UI実装"

# 6. 全テスト実行
# npm test

# 7. ベースブランチにプッシュ
git push origin $baseBranch

# マージ順序の原則:
#   基盤層（DB/スキーマ）→ 共有層（型/API）→ 表示層（UI）
#   = 依存される側から依存する側へ
```

---

## Step 8（staging 経由の場合）: プレビュー E2E → 本番マージ

ベースブランチが `staging` の場合、全 worktree のマージ後に以下を実行する。

```powershell
# === staging → E2E → main フロー ===

# 1. staging へのプッシュで自動デプロイが走る（5分待機）
Write-Host "プレビュー環境へのデプロイ待機中..." -ForegroundColor Cyan
Start-Sleep -Seconds 300

# 2. プレビュー環境で E2E テスト
#    → Playwright MCP 等で動作確認
#    → 各プロジェクトの E2E チェックリストに従う

# 3. E2E テスト成功後、staging → main の PR を作成
gh pr create --base main --head staging --title "Release: 機能名" --body "E2Eテスト完了"

# 4. マージ（--merge 推奨。squash は大量コミット時にコード重複リスクあり）
gh pr merge --merge

# 5. 本番デプロイ待機 → 本番確認
Start-Sleep -Seconds 300

# 注意:
#   - staging → main は --merge を使用（squash はコード重複リスクあり）
#   - 各プロジェクトのマージガイドがあればそれに従う
#   - 本番デプロイ失敗時は main から hotfix ブランチで緊急対応
```

---

## staging → main マージ（worktree 統合後）

全 worktree を staging にマージし、プレビュー環境で E2E テストを実施した後:

```powershell
# 1. プレビュー環境で E2E テスト完了を確認

# 2. staging → main の PR を作成
gh pr create --base main --head staging --title "Release: 機能名" --body "E2Eテスト完了"

# 3. マージ（--merge 推奨。squash は大量コミット時にコード重複リスクあり）
gh pr merge --merge

# 4. 本番デプロイ完了を待機して確認
```

**重要**: staging → main のマージには `--merge`（マージコミット）を推奨。
`--squash` は同一ファイルを複数 PR で修正している場合にコード重複リスクがある。
詳細は各プロジェクトのマージガイドを参照。

---

## マージ競合の解決

### 競合が発生しやすいファイルと対策

| ファイル | 競合パターン | 推奨解決方法 |
|---------|-------------|-------------|
| `package.json` | 依存パッケージの追加が競合 | 手動マージ: 両方の追加を残す |
| `package-lock.json` | ほぼ確実に競合 | 一方を採用後 `npm install` で再生成 |
| `types/index.ts` | 型定義の追加が競合 | 両方の追加を残す（名前衝突に注意） |
| `src/index.ts` | エントリーポイントの変更 | 手動マージ: import/export を統合 |
| `.env.example` | 環境変数の追加 | 両方の追加を残す |
| `prisma/schema.prisma` | モデル追加が競合 | 両方のモデルを残す（関連確認） |

### 競合解決の PowerShell ヘルパー

```powershell
# === マージ競合の自動検出と解決支援 ===

function Resolve-MergeConflicts {
    param(
        [string]$Strategy = "manual"  # manual | ours | theirs
    )

    $conflicts = git diff --name-only --diff-filter=U
    if (-not $conflicts) {
        Write-Host "競合なし" -ForegroundColor Green
        return
    }

    Write-Host "=== 競合ファイル一覧 ===" -ForegroundColor Yellow
    $conflicts | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }

    switch ($Strategy) {
        "ours" {
            $conflicts | ForEach-Object { git checkout --ours $_ }
            Write-Host "全て自分側で解決しました" -ForegroundColor Cyan
        }
        "theirs" {
            $conflicts | ForEach-Object { git checkout --theirs $_ }
            Write-Host "全て相手側で解決しました" -ForegroundColor Cyan
        }
        "manual" {
            Write-Host "手動解決が必要です。各ファイルのコンフリクトマーカーを確認してください。" -ForegroundColor Yellow
        }
    }
}

# lockfile 競合の特別処理
function Resolve-LockfileConflict {
    param(
        [string]$PackageManager = "npm"  # npm | pnpm | yarn
    )

    switch ($PackageManager) {
        "npm" {
            git checkout --theirs package-lock.json
            npm install
            git add package-lock.json
        }
        "pnpm" {
            git checkout --theirs pnpm-lock.yaml
            pnpm install
            git add pnpm-lock.yaml
        }
        "yarn" {
            git checkout --theirs yarn.lock
            yarn install
            git add yarn.lock
        }
    }
    Write-Host "Lockfile を再生成しました" -ForegroundColor Green
}
```

### マージ前の事前チェック（dry-run）

```powershell
# マージ前に競合が発生するか確認（実際にはマージしない）
function Test-MergeDryRun {
    param(
        [string]$Branch
    )

    # merge --no-commit --no-ff で試行
    $result = git merge --no-commit --no-ff $Branch 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "マージ可能: $Branch は競合なしでマージできます" -ForegroundColor Green
    } else {
        Write-Host "競合あり: $Branch のマージで以下のファイルが競合します" -ForegroundColor Red
        git diff --name-only --diff-filter=U
    }

    # 試行を元に戻す
    git merge --abort 2>$null
}

# 使用例: 全ブランチの事前チェック
@("feature/db", "feature/api", "feature/ui") | ForEach-Object {
    Write-Host "`n--- $_  ---" -ForegroundColor Cyan
    Test-MergeDryRun -Branch $_
}
```
