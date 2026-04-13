<!-- 抽出元: SKILL.md のセクション「前提条件」「ベースブランチ戦略」 -->

# git worktree ベースブランチ戦略

## 前提条件

### git バージョン確認

```powershell
git --version
# git version 2.20 以上が必要（worktree は 2.5 で導入、2.20 で安定化）
```

### リポジトリ要件

- git 管理されたリポジトリであること
- メインの worktree が**クリーンな状態**であること（未コミットの変更なし）
- 十分なディスク容量があること（worktree ごとにファイルのコピーが作成される）

### 単独worktree使用時の必須手順（EnterWorktreeツール使用時）

Claude Code の `EnterWorktree` ツールは**現在のHEADからworktreeを作成する**。
そのため、別のfeatureブランチにいる状態でworktreeを作成すると、
mainやstagingの最新変更が含まれないworktreeが作成される。

**必ず以下を実行してからworktreeを作成すること:**

```bash
# 1. 現在のブランチを確認
git branch --show-current

# 2. ベースブランチに切り替えて最新化
git checkout $baseBranch
git pull origin $baseBranch

# 3. この状態でworktreeを作成（EnterWorktreeツール or git worktree add）
```

**特に危険なパターン:**
- featureブランチにいる状態 → そのままworktree作成 → 古いmainベースで作業
- mainが大幅に進んでいる場合（例: 100+コミット遅れ）→ 既存ファイルの最新変更が全て欠落
- 既にmainに存在するファイル（Privacy.tsx等）を編集する場合 → 最新変更が上書きされるリスク

---

## ベースブランチ戦略

worktree の分岐元（ベースブランチ）は**プロジェクトのブランチ運用に合わせて変更する**。

### ブランチモデル別の設定

| ブランチモデル | ベースブランチ | マージ先 | 本番反映 |
|---------------|-------------|---------|---------|
| **シンプル**（main のみ） | `main` | `main` | マージで即反映 |
| **staging 経由**（推奨） | `staging` | `staging` | staging → E2E → main |
| **develop 経由** | `develop` | `develop` | develop → staging → main |

### staging 経由フロー（Vercel + プレビュー環境がある場合）

staging ブランチがプレビュー環境にデプロイされるプロジェクトでは、**worktree のベースを `staging` にする**。

```
正しいフロー（staging 経由）:
  worktree branches ──→ staging ──→ プレビュー E2E ──→ main
                        (マージ先)   (自動デプロイ)      (本番)

誤ったフロー（main 直接）:
  worktree branches ──→ main（E2Eなしで本番反映される）
```

```powershell
# === ベースブランチ設定 ===

# シンプルモデル
$baseBranch = "main"

# staging 経由モデル（Vercel Preview 等）
$baseBranch = "staging"

# 以降の全スクリプトで $baseBranch を使用する
```
