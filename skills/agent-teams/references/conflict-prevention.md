<!-- 抽出元: SKILL.md のセクション「コアルール: ファイル競合防止」「アンチパターン」「関連スキル」「参考」 -->

# Agent Teams ファイル競合防止・アンチパターン

## コアルール: ファイル競合防止

**Agent Teamsの最大リスクは、複数エージェントが同じファイルを同時編集して上書きし合うこと。**
以下のルールでこれを完全に防止する。

### ルール1: 排他的ファイル所有権（1ファイル = 1オーナー）

| 原則 | 説明 |
|------|------|
| **1ファイル1オーナー** | 各ファイルは1人のワーカーだけが書き込み可能 |
| **所有権は事前確定** | タスク開始前にファイル割当を完了する |
| **禁止ファイルの明示** | 各ワーカーに「触ってはいけないファイル」を明示する |
| **新規ファイル作成** | 自分の担当ディレクトリ内でのみ許可 |

### ルール2: 共有ファイルの管理

共有ファイル（型定義、config、package.json等）は特に危険。**必ず1人だけが変更権を持つ。**

```
共有ファイルの例:
  types/index.ts        → Worker A が single_writer
  package.json          → リーダーが管理（またはWorker 1人に委任）
  tsconfig.json         → 変更禁止（事前に設定完了しておく）
  .env                  → 変更禁止
  src/index.ts          → Worker A が single_writer
  src/lib/constants.ts  → 変更禁止（事前に定義完了しておく）
```

### ルール3: 競合ゾーンの事前特定

タスク開始前に、以下のパターンを必ずチェックする。

| 競合ゾーン | 例 | 対策 |
|-----------|-----|------|
| エントリーポイント | `src/index.ts`, `src/App.tsx` | 1人だけが編集 |
| パッケージ管理 | `package.json`, `requirements.txt` | 依存追加は1人が集約 |
| 共有型定義 | `types/*.ts`, `interfaces/` | single_writerモード |
| 設定ファイル | `tsconfig.json`, `.eslintrc` | 変更禁止（事前完了） |
| ルーティング | `routes/index.ts`, `app/layout.tsx` | 1人だけが編集 |
| DB スキーマ | `schema.prisma`, `migrations/` | 1人だけが編集 |

### ルール4: リーダーの権限モード

リーダーは **delegate モード**を推奨。チームメイトに適切な権限を委譲する。

```
Task tool:
  mode: "delegate"       # チームメイトに実行権限を委譲
  subagent_type: "general-purpose"
```

### ルール5: 所有権移譲プロトコル

タスク進行中にファイル所有権の移譲が必要になった場合、以下の手順を必ず踏む。

```
所有権移譲の3ステップ:

1. 移譲元が SendMessage で通知
   → 理由（reason）、対象ファイル（files）を明記

2. 移譲先が SendMessage で受領確認（receiver_ack）
   → 受け取ったファイル一覧を復唱

3. 移譲元が当該ファイルの編集を停止
   → 受領確認を受けるまで編集を続けてはならない
```

**重要**: 受領確認なしに所有権は移譲されない。移譲元はACKを受けるまで当該ファイルの書き込み責任を持つ。

### ルール6: 統合前競合検査

全ワーカーの作業完了後、統合前に変更ファイルの重複がないか自動チェックする。

```powershell
# 統合前競合検査スクリプト（PowerShell）
# 各ワーカーの変更ファイルを取得し、重複を検出

$workers = @("worker-a", "worker-b", "worker-c")  # ワーカーのブランチ名
$baseRef = "main"  # ベースブランチ
$allFiles = @{}

foreach ($worker in $workers) {
    $files = git diff --name-only "$baseRef...$worker"
    foreach ($file in $files) {
        if ($allFiles.ContainsKey($file)) {
            $allFiles[$file] += ", $worker"
            Write-Warning "競合検出: $file は複数ワーカーが変更 ($($allFiles[$file]))"
        } else {
            $allFiles[$file] = $worker
        }
    }
}

# 重複なければOK
$conflicts = $allFiles.GetEnumerator() | Where-Object { $_.Value -match "," }
if ($conflicts.Count -eq 0) {
    Write-Host "競合なし: 統合可能です" -ForegroundColor Green
} else {
    Write-Host "競合あり: 以下のファイルを手動確認してください" -ForegroundColor Red
    $conflicts | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }
}
```

**ブランチを使わない場合**: 各ワーカーに「変更したファイル一覧」を報告させ、リーダーが重複チェックを行う。

---

## アンチパターン

| アンチパターン | なぜ危険か | 正しいやり方 |
|---------------|----------|-------------|
| **所有権マップなしで開始** | 確実にファイル競合が発生する | Step 3 を必ず完了してからスポーン |
| **「後で調整する」** | 上書きされたコードは復元困難 | 事前に所有権を確定する |
| **package.json を複数人が編集** | 依存関係の競合、lockfile の破壊 | 1人だけが管理する |
| **型定義ファイルの同時編集** | 片方の変更が消える | single_writer を指定 |
| **口頭の所有権合意** | 忘れる、認識がズレる | YAMLテンプレートで明文化 |
| **ワーカー5人以上** | 管理不能、通信コスト爆発 | 最大4人、2人から開始 |
| **依存タスクの並列実行** | 前提が整っていない状態で実装が進む | blockedBy で順序制御 |
| **統合順序がランダム** | 型エラーが連鎖して収拾不能 | 基盤層から固定順序で統合 |
| **所有権移譲を暗黙に実行** | 二重編集のリスク | 移譲プロトコル（3ステップ）を厳守 |
| **テスト担当がアイドル** | リソースの無駄 | 先行作業（モック・フィクスチャ）を割り当て |
| **変更ファイルの報告を省略** | 統合時に競合を検出できない | 全ワーカーが変更ファイル一覧を報告 |
| **コミット前にTeamDeleteを実行** | worktreeディレクトリが削除され、未コミットの変更が全て失われる | **必ずコミット&プッシュしてからTeamDeleteを実行する**。TeamDeleteはworktreeの物理ディレクトリを削除するため、git管理されていない変更は復元不可能 |

---

## 関連スキル

- **`/git-worktree-parallel`**: git worktree を使った並行実装。ワーカーごとに独立ディレクトリを提供し、ファイル競合をOSレベルで完全防止。Agent Teams との併用推奨
- **`/github-cli`**: PR作成・マージのワークフロー。統合後のPR管理に使用

## 参考

- Agent Teams は Claude Code の実験的機能
- TeamCreate / TaskCreate / SendMessage 等のツールで操作
- ワーカーのスポーンには Task tool を使用（subagent_type: "general-purpose"）
