---
name: git-worktree-parallel
description: |
  git worktreeを使った並行実装。Agent Teamsと組み合わせてワーカーごとに独立作業ディレクトリを提供。
  トリガー: "worktree", "ワークツリー", "並行ブランチ", "worktreeで分担",
  "ブランチ分離で開発", "worktree並列"
  使用場面: (1) Agent Teamsワーカーに物理的に分離された作業環境を提供、
  (2) 複数ブランチの同時作業、(3) ファイル競合をOSレベルで完全防止
  関連スキル: agent-teams-coding
---

# git worktree 並行実装スキル

## 概要

`git worktree` を使い、**1つのリポジトリから複数の作業ディレクトリ（worktree）を作成**して並行開発を行う。
Agent Teams スキル（`/agent-teams-coding`）と組み合わせることで、ファイル競合を**OSレベル**で完全に防止する。

```
リポジトリ（メイン）
C:\project\my-app\                    ← メイン worktree（ベースブランチ）
│
├── .git\                             ← 全 worktree で共有（実体はここだけ）
│
├─ worktrees/
│   ├── wt-api\   → C:\project\wt-api\      ← Worker A（feature/api ブランチ）
│   └── wt-ui\    → C:\project\wt-ui\       ← Worker B（feature/ui ブランチ）
│
│  ┌──────────────────────────────────────────────────┐
│  │  各 worktree は完全に独立したディレクトリ        │
│  │  → 同じファイルを同時編集しても物理的に競合しない │
│  │  → .git は共有なので git 操作は相互に見える      │
│  └──────────────────────────────────────────────────┘
│
└── 最終的にベースブランチへ順次マージ
```

---

## 核心ルール

1. **1ワーカー = 1 worktree = 1ブランチ = 1ディレクトリ**
2. **worktree作成前にベースブランチを最新化**: `git checkout $baseBranch && git pull origin $baseBranch`
3. **メイン worktree は常にクリーン**: マージ先の汚染を防ぐ
4. **マージ順序は固定**: 基盤層（DB/スキーマ）→ 共有層（型/API）→ 表示層（UI）
5. **primary_scope 外の変更は最小限**: マージ競合を予防
6. **staging → main は --merge を使用**: --squash はコード重複リスクあり
7. **worktree削除は `git worktree remove` を使用**: 手動削除するとゴミが残る
8. **各 worktree で npm install を実行**: メインだけでは不足
9. **コミット&プッシュ後に TeamDelete**: 未コミット変更が消失するのを防止
10. **Windows MAX_PATH 対策**: パスを短く保つ（`C:\wt\api` 等）、`core.longpaths true`

---

## agent-teams スキルとの関係

| アプローチ | 競合防止の仕組み | 強度 | 適用場面 |
|-----------|----------------|------|---------|
| **agent-teams のみ** | ファイル所有権ルール（ソフト制約） | 中 | 担当を明確に分離できる場合 |
| **worktree + agent-teams** | 物理ディレクトリ分離（ハード制約） | 高 | 大規模変更、安全重視の場合 |
| **worktree のみ** | ディレクトリ分離のみ | 中 | 少人数で担当範囲が明確な場合 |

**推奨**: Agent Teams を使う場合は **worktree + agent-teams の併用** が最も安全。

---

## クイックスタート

### 1. worktree の作成

```powershell
# メインリポジトリでベースブランチを最新化
Set-Location "C:\project\my-app"
git checkout staging        # ベースブランチ（main / staging / develop）
git pull origin staging

# worktree 作成
git worktree add ../wt-api -b feature/api
git worktree add ../wt-ui -b feature/ui
git worktree add ../wt-db -b feature/db

# 確認
git worktree list
```

### 2. 各 worktree で依存インストール

```powershell
Set-Location "C:\project\wt-api"; npm install
Set-Location "C:\project\wt-ui"; npm install
Set-Location "C:\project\wt-db"; npm install
```

### 3. 順次マージ（作業完了後）

```powershell
Set-Location "C:\project\my-app"
git checkout staging
git merge feature/db --no-ff -m "Merge feature/db: DB層実装"
git merge feature/api --no-ff -m "Merge feature/api: API実装"
git merge feature/ui --no-ff -m "Merge feature/ui: UI実装"
git push origin staging
```

### 4. クリーンアップ

```powershell
git worktree remove ../wt-api
git worktree remove ../wt-ui
git worktree remove ../wt-db
git worktree prune
```

---

## ベースブランチ戦略（概要）

| ブランチモデル | ベースブランチ | マージ先 | 本番反映 |
|---------------|-------------|---------|---------|
| **シンプル**（main のみ） | `main` | `main` | マージで即反映 |
| **staging 経由**（推奨） | `staging` | `staging` | staging → E2E → main |
| **develop 経由** | `develop` | `develop` | develop → staging → main |

**重要**: staging 経由の場合、worktree ブランチは staging にマージする。main に直接マージしない。

---

## 6フェーズ実行チェックリスト

```
Phase 1: 準備        → ベースブランチ決定・最新化・worktree作成・npm install
Phase 2: 並行作業    → TeamCreate・ワーカースポーン・実装
Phase 3: 統合        → dry-run → 順次マージ → 型チェック+テスト
Phase 4: プレビュー検証 → デプロイ待機 → E2Eテスト
Phase 5: 本番リリース  → staging→main PR → マージ → 本番確認
Phase 6: クリーンアップ → worktree削除 → ブランチ削除 → TeamDelete
```

---

## 詳細リファレンス

references/agent-teams-integration.md
- worktree-per-worker モデル（基本原則、なぜ worktree が最適か）
- Agent Teams 連携の実行フロー（Step 0〜Step 5 補足）
- worktree 一括作成スクリプト（PowerShell）
- worktree 所有権契約テンプレート（YAML）
- ワーカースポーン時のプロンプト例
- git worktree コマンドリファレンス（作成・一覧・削除・ロック）
- worktree クリーンアップスクリプト
- 完全実行フローチェックリスト（6フェーズ詳細）
- Windows 環境での注意事項（MAX_PATH、ロックファイル、node_modules等）
- アンチパターン一覧（12項目）
- トラブルシューティング

references/merge-strategy.md
- 順次マージ戦略（推奨手順、マージ順序の原則）
- staging → E2E → main フロー
- staging → main マージの注意点（--merge 推奨）
- マージ競合が発生しやすいファイルと対策一覧
- 競合解決 PowerShell ヘルパー（Resolve-MergeConflicts、Resolve-LockfileConflict）
- マージ前 dry-run チェック（Test-MergeDryRun）

references/base-branch-strategy.md
- 前提条件（gitバージョン、リポジトリ要件）
- EnterWorktreeツール使用時の必須手順
- 危険なパターン（古いベースからのworktree作成）
- ベースブランチ戦略（シンプル / staging経由 / develop経由）
- staging 経由フロー（Vercel + プレビュー環境）

---

## 関連スキル

- **`/agent-teams-coding`**: Agent Teamsの並列コーディングオーケストレーション。worktree と併用推奨
- **`/github-cli`**: PR作成・マージのワークフロー。worktree ブランチのPR管理に使用
- **`/usacon`**: staging 経由フローの実例。`$baseBranch = "staging"` で使用

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| worktree作成失敗（ブランチ既存） | `git branch -D <branch>` で既存ブランチを削除してから再作成 |
| .git/HEAD DENY ACL | 他のAIエージェントが並列作業中。完了を待つかHEAD変更不要な操作に限定 |
| worktreeディレクトリが残る | `git worktree prune` でorphanedエントリを削除 |
| node_modules不足 | worktree内で `npm install` を実行（親リポジトリとは独立） |

## worktreeチェックリスト

- [ ] ベースブランチが最新か（`git pull` 済み）
- [ ] worktreeパスが既存ディレクトリと重複していないか
- [ ] 作業完了後にworktreeを削除したか（`git worktree remove`）

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2025-12 | 初版作成 | git worktree並行実装パターンの標準化 |
| 2026-03-18 | トラブルシューティング・改訂履歴・チェックリスト追加 | skill-improve audit対応 |
