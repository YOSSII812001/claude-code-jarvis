<!-- 抽出元: SKILL.md のセクション「実行フロー（Agent Teams 連携）」「コアコンセプト: worktree-per-worker モデル」「git worktree コマンドリファレンス」「Windows 環境での注意事項」「トラブルシューティング」「完全実行フロー（チェックリスト）」「アンチパターン」「関連スキル」 -->

# git worktree Agent Teams 統合

## コアコンセプト: worktree-per-worker モデル

### 基本原則

```
1ワーカー = 1 worktree = 1ブランチ = 1ディレクトリ

Worker A → C:\project\wt-api\   (feature/api ブランチ)
Worker B → C:\project\wt-ui\    (feature/ui ブランチ)
Worker C → C:\project\wt-db\    (feature/db ブランチ)
```

### なぜ worktree が並行開発に最適か

| 問題 | 通常の git | worktree |
|------|-----------|----------|
| 同時に複数ブランチで作業 | `git stash` → `checkout` の繰り返し | 各 worktree で直接作業 |
| ファイルの上書き競合 | 同一ディレクトリなので常にリスク | 物理的に別ディレクトリなので不可能 |
| node_modules 等の再構築 | ブランチ切替のたびに発生しうる | 各 worktree で独立管理 |
| ロックファイルの競合 | 同一 .git を直接操作して競合 | worktree ごとに独立した index |

---

## agent-teams スキルとの関係

| アプローチ | 競合防止の仕組み | 強度 | 適用場面 |
|-----------|----------------|------|---------|
| **agent-teams のみ** | ファイル所有権ルール（ソフト制約） | 中 | 同一ディレクトリで作業、担当を明確に分離できる場合 |
| **worktree + agent-teams** | 物理ディレクトリ分離（ハード制約） | 高 | 担当が重なりやすい場合、大規模変更、安全重視の場合 |
| **worktree のみ** | ディレクトリ分離のみ（マージで競合解決） | 中 | 少人数で担当範囲が明確、マージ戦略で対処可能な場合 |

**推奨**: Agent Teams を使う場合は **worktree + agent-teams の併用** が最も安全。

---

## 実行フロー（Agent Teams 連携）

agent-teams スキルの 7ステップフローと連携する形で使用する。

### Step 0: worktree 環境準備（agent-teams の Step 1 の前に実行）

**入力**: プロジェクトディレクトリ、ワーカー数
**出力**: 各ワーカー用の worktree ディレクトリ
**完了条件**: 全 worktree が作成され、ブランチが正しく設定されている

```powershell
# === worktree 一括作成スクリプト（PowerShell） ===

$projectDir = "C:\project\my-app"    # メインリポジトリ
$baseDir    = "C:\project"           # worktree の親ディレクトリ
$baseBranch = "staging"              # ベースブランチ（プロジェクトに合わせて変更: main / staging / develop）

# メインリポジトリで最新を取得
Set-Location $projectDir
git checkout $baseBranch
git pull origin $baseBranch

# ワーカー定義（名前 → ブランチ名）
$workers = @{
    "wt-api" = "feature/api"
    "wt-ui"  = "feature/ui"
    "wt-db"  = "feature/db"
}

# worktree 作成
foreach ($entry in $workers.GetEnumerator()) {
    $wtPath = Join-Path $baseDir $entry.Key
    $branch = $entry.Value

    if (Test-Path $wtPath) {
        Write-Warning "既に存在: $wtPath（スキップ）"
        continue
    }

    Write-Host "作成中: $wtPath ($branch)" -ForegroundColor Cyan
    git worktree add $wtPath -b $branch
}

# 確認
Write-Host "`n=== 現在の worktree 一覧 ===" -ForegroundColor Green
git worktree list
```

### Step 2-3 への補足: worktree 使用時の所有権マップ

worktree モデルでは、所有権は**ディレクトリ単位**で自動的に分離される。
ただし、共有ファイル（型定義等）の扱いは依然として重要。

```yaml
# === worktree 所有権契約（agent-teams テンプレートの拡張） ===
worktree_ownership:
  worker-api:
    worktree_path: "C:/project/wt-api"
    branch: "feature/api"
    primary_scope: "src/api/**, tests/api/**"
    # worktree 内では全ファイル編集可能だが、
    # マージ時の競合を避けるため primary_scope 外の変更は最小限に

  worker-ui:
    worktree_path: "C:/project/wt-ui"
    branch: "feature/ui"
    primary_scope: "src/ui/**, src/components/**, tests/ui/**"

  worker-db:
    worktree_path: "C:/project/wt-db"
    branch: "feature/db"
    primary_scope: "src/db/**, prisma/**, tests/db/**"

# 共有ファイルの扱い（重要）
shared_files_strategy:
  types/index.ts:
    writer: "worker-api"      # API側が型を定義
    others: "readonly"        # 他ワーカーは参照のみ（同じ型を使える）
    merge_note: "最初にマージ"

  package.json:
    writer: "leader"          # リーダーが統合時に対応
    others: "append-only"     # 依存追加のみ許可、既存の変更禁止
    merge_note: "手動マージ必須"
```

### Step 5 への補足: ワーカースポーン時のプロンプト

```
Task tool（worktree 使用時のワーカースポーン）:
  subagent_type: "general-purpose"
  team_name: "feature-auth"
  name: "worker-api"
  mode: "delegate"
  prompt: |
    あなたは認証API実装の担当です。

    ## 作業ディレクトリ（重要）
    あなたの作業ディレクトリは以下です。このディレクトリ内でのみ作業してください:
      C:\project\wt-api\

    メインリポジトリ（C:\project\my-app\）は絶対に変更しないでください。

    ## ブランチ
    あなたのブランチ: feature/api
    ベースブランチ: staging（※プロジェクトに応じて main / staging / develop）

    ## 担当範囲（primary_scope）
    主に以下のファイルを実装してください:
      - src/api/**
      - tests/api/**

    ## 共有ファイルの扱い
    - types/index.ts: あなたが型定義を追加してOK
    - package.json: 依存パッケージの追加のみOK（既存の変更禁止）
    - その他の共有ファイル: 変更しない

    ## 依存パッケージが必要な場合
    worktree 内で npm install を実行してください:
      Set-Location "C:\project\wt-api"
      npm install <package-name>

    ## 完了時の報告
    1. 変更ファイル一覧: git diff --name-only $baseBranch...feature/api
    2. テスト結果
    3. 未解決の問題
```

---

## git worktree コマンドリファレンス

### worktree の作成

```powershell
# 基本: 新しいブランチを作って worktree を作成
git worktree add <パス> -b <新ブランチ名>

# 例: メインリポジトリの隣に作成（推奨）
git worktree add ../wt-api -b feature/api
git worktree add ../wt-ui -b feature/ui
git worktree add ../wt-db -b feature/db

# 既存ブランチをチェックアウトして worktree を作成
git worktree add ../wt-hotfix hotfix/urgent-fix

# 特定のコミットから worktree を作成
git worktree add ../wt-review HEAD~5
```

### worktree の一覧確認

```powershell
git worktree list
# 出力例:
# C:/project/my-app     abc1234 [main]
# C:/project/wt-api     def5678 [feature/api]
# C:/project/wt-ui      ghi9012 [feature/ui]

# 詳細表示（porcelain形式: スクリプト向け）
git worktree list --porcelain
```

### worktree の削除

```powershell
# worktree を削除（ディレクトリも削除される）
git worktree remove ../wt-api

# 強制削除（未コミットの変更がある場合）
git worktree remove --force ../wt-api

# ディレクトリを手動削除した場合のクリーンアップ
git worktree prune
```

### worktree のロック/アンロック

```powershell
# worktree をロック（誤って prune されるのを防ぐ）
git worktree lock ../wt-api --reason "Worker A が作業中"

# アンロック
git worktree unlock ../wt-api
```

---

## worktree クリーンアップ

### 全 worktree の一括削除

```powershell
# === worktree 一括クリーンアップスクリプト ===

$projectDir = "C:\project\my-app"
Set-Location $projectDir

# メイン以外の worktree を一覧取得
$worktrees = git worktree list --porcelain |
    Select-String "^worktree " |
    ForEach-Object { ($_ -replace "^worktree ", "").Trim() } |
    Where-Object { $_ -ne $projectDir }

if ($worktrees.Count -eq 0) {
    Write-Host "削除する worktree はありません" -ForegroundColor Green
    return
}

Write-Host "=== 削除対象の worktree ===" -ForegroundColor Yellow
$worktrees | ForEach-Object { Write-Host "  $_" }

# 削除実行
foreach ($wt in $worktrees) {
    Write-Host "削除中: $wt" -ForegroundColor Cyan
    git worktree remove $wt --force
}

# 残骸をクリーンアップ
git worktree prune

Write-Host "`nクリーンアップ完了" -ForegroundColor Green
git worktree list
```

### マージ済みブランチの削除

```powershell
# マージ済みの feature ブランチを一括削除（$baseBranch にマージ済みのもの）
$baseBranch = "staging"  # プロジェクトに合わせて変更
git branch --merged $baseBranch |
    Select-String "feature/" |
    ForEach-Object { $_.ToString().Trim() } |
    ForEach-Object {
        Write-Host "削除: $_" -ForegroundColor Yellow
        git branch -d $_
    }
```

---

## 完全実行フロー（チェックリスト）

Agent Teams + worktree の完全な実行フロー。

```
Phase 1: 準備
  [] ベースブランチを決定（main / staging / develop）
  [] git pull origin $baseBranch で最新化
  [] worktree 一括作成スクリプト実行
  [] 各 worktree で依存インストール（npm install 等）
  [] 所有権契約（worktree 版）を作成

Phase 2: 並行作業（Agent Teams）
  [] TeamCreate でチーム作成
  [] 各ワーカーを worktree パス指定でスポーン
  [] ワーカーが自分の worktree 内で実装
  [] リーダーが TaskList で進捗監視

Phase 3: ベースブランチへの統合
  [] 全ワーカーがコミット完了を報告
  [] マージ前 dry-run チェック（Test-MergeDryRun）
  [] $baseBranch に順次マージ（基盤層 → 共有層 → 表示層）
  [] 各マージ後に型チェック + テスト
  [] 競合があれば手動解決
  [] $baseBranch にプッシュ

Phase 4: プレビュー検証（staging 経由の場合）
  [] デプロイ完了を待機（5分程度）
  [] プレビュー環境で E2E テスト実施
  [] E2E テスト成功を確認

Phase 5: 本番リリース（staging 経由の場合）
  [] staging → main の PR 作成
  [] PR マージ（--merge 推奨）
  [] 本番デプロイ完了を確認
  [] 本番環境で最終確認

Phase 6: クリーンアップ
  [] worktree 一括削除
  [] マージ済みブランチ削除
  [] チームシャットダウン & TeamDelete
```

---

## Windows 環境での注意事項

| 注意点 | 説明 | 対策 |
|--------|------|------|
| **パスの長さ** | Windows の MAX_PATH (260文字) 制限 | worktree パスを短くする（`C:\wt\api` 等） |
| **ロックファイル** | `.git/worktrees/` 内のロックが残る | `git worktree prune` で解消 |
| **node_modules** | 各 worktree で独立して `npm install` が必要 | worktree 作成直後に実行 |
| **ファイル監視** | IDE が複数 worktree を監視するとCPU負荷 | IDE で開く worktree は1つに絞る |
| **シンボリックリンク** | Windows ではシンボリックリンクに権限が必要な場合がある | `git config core.symlinks false` |
| **パス区切り文字** | git は `/` を推奨、PowerShell は `\` | git コマンド内では `/` を使用 |

### MAX_PATH 対策

```powershell
# git の long paths 対応を有効化（推奨）
git config --global core.longpaths true

# worktree パスを短く保つ命名規則
# 良い例:
#   C:\wt\api
#   C:\wt\ui
# 悪い例:
#   C:\Users\username\Documents\projects\my-long-project-name\worktrees\feature-api-implementation
```

---

## アンチパターン

| アンチパターン | なぜ危険か | 正しいやり方 |
|---------------|----------|-------------|
| **メイン worktree で直接作業** | 他ワーカーのマージ先が汚染される | メインは常にクリーンに保つ |
| **worktree 間でファイルコピー** | git の追跡外になり、マージ時に消える | git merge で統合する |
| **同じブランチの worktree を複数作成** | git が許可しない（エラーになる） | 1ブランチ = 1 worktree |
| **worktree ディレクトリを手動削除** | `.git/worktrees/` にゴミが残る | `git worktree remove` を使う |
| **全 worktree で共有ファイルを変更** | マージ時に必ず競合する | primary_scope 外の変更は最小限に |
| **npm install をメインだけで実行** | 各 worktree で node_modules が必要 | worktree ごとに npm install |
| **worktree を長期間放置** | ベースブランチとの乖離が拡大 | 作業完了後すぐにマージ & 削除 |
| **worktree 内から別の worktree を操作** | パスの混乱、意図しない変更 | 自分の worktree 内だけで作業 |
| **staging 経由なのに main に直接マージ** | E2E テストなしで本番反映 | ベースブランチ戦略を確認 |
| **staging → main で --squash を使用** | 大量コミット時にコード重複リスク | --merge を使用 |
| **Agent TeamsのTeamDelete前にコミットしない** | TeamDeleteがworktreeディレクトリを削除し、未コミットの変更が全て消失する | **必ずgit add → commit → pushしてからTeamDeleteを実行する**（詳細: `/agent-teams-coding` スキル参照） |
| **古いベースからworktreeを作成** | 古いmainベースで作業開始、既存ファイルの最新変更が全て欠落・上書きされる（例: 100+コミット遅れ） | worktree作成前に `git checkout $baseBranch && git pull origin $baseBranch` で最新化 |

---

## トラブルシューティング

### "fatal: is already checked out" エラー

```powershell
# 原因: そのブランチが既に別の worktree でチェックアウトされている
# 解決: 新しいブランチ名を使う
git worktree add ../wt-api -b feature/api-v2

# または既存の worktree を削除してから再作成
git worktree remove ../wt-api
git worktree add ../wt-api -b feature/api
```

### worktree が壊れた場合

```powershell
# worktree の状態をリセット
git worktree prune            # 無効な worktree エントリを削除
git worktree list             # 現在の状態を確認
git worktree repair           # 壊れた worktree を修復（git 2.30+）
```

### worktree 内で git status が遅い場合

```powershell
# fsmonitor を有効化（Windows で大規模リポジトリの場合に有効）
git config core.fsmonitor true
git config core.untrackedcache true
```

---

## 関連スキル

- **`/agent-teams-coding`**: Agent Teamsの並列コーディングオーケストレーション。worktree と併用推奨
- **`/github-cli`**: PR作成・マージのワークフロー。worktree ブランチのPR管理に使用
- **`/usacon`**: staging 経由フローの実例。`$baseBranch = "staging"` で使用
