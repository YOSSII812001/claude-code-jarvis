# デプロイ待機・vercel-watch 詳細

## PRマージ後のデプロイ待機（vercel-watch推奨）

PRをマージした後、テスト前にデプロイ完了を確認すること。
Vercelのビルド＋CDN反映が完了するまで時間がかかるため、早すぎるテストは古いコードで実行される。

> **推奨:** `vercel-watch` スキルでデプロイ完了を実検知する。固定sleep待機より確実かつ高速。
> 詳細: `~/.claude/skills/vercel-watch/SKILL.md`

| 環境 | 方法（推奨） | フォールバック |
|------|-------------|--------------|
| **staging** (preview) | `vercel-watch -WaitForReady -Environment Preview` | sleep 180（3分固定） |
| **main** (本番) | `vercel-watch -WaitForReady -Environment Production` | sleep 300（5分固定） |

### 推奨: vercel-watch -WaitForReady によるデプロイ完了検知

**PRマージ直後にバックグラウンドで監視を開始し、Ready検知後に自動終了:**

> **重要:** `-WaitForReady` フラグを必ず付けること。このフラグなしでは無限ループとなり、
> `TaskOutput` がプロセス終了を待ってブロックし続ける問題が発生する。

> **Continuousモード（`-WaitForReady` なし）はバックグラウンド実行禁止:**
> `-Environment Production -Interval 15` のみ指定するContinuousモードは、Ready検知後もプロセスが終了せず
> ポーリングを続けるため、`run_in_background` で起動するとTaskOutput通知が永遠に届かない。
> バックグラウンド実行時は必ず `-WaitForReady` を使用すること。

```
Bashツール（run_in_background: true, timeout: 360000）:

# staging（Preview）デプロイ監視 — Ready検知後に自動exit 0
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Preview -Interval 10

# main（Production）デプロイ監視 — Ready検知後に自動exit 0
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Production -Interval 10
```

**動作の流れ:**
1. ポーリング開始 → Building状態のデプロイを検知
2. Building → Ready/Error/Canceled への遷移を監視
3. 全Buildingが完了 → exit 0（成功）or exit 1（Errorあり）でプロセス終了
4. TaskOutput通知を受信 → E2Eテスト開始

### ⚠️ 本番デプロイの2段階構造（重要）

mainブランチへのマージ後、本番環境（usacon-ai.com）のデプロイは**2段階**で行われる：

| 順序 | アカウント | トリガー | 結果 |
|------|-----------|---------|------|
| 1回目 | YOSSII812001 | mainマージ → 自動デプロイ | Vercelに表示されるが**usacon-ai.comには反映されない** |
| 2回目 | robbits0802（本アカウント） | 1回目完了後に自動再デプロイ | **usacon-ai.comに反映される** |

**vercel-watch使用時の注意:**
- `-Environment Production` で監視する場合、1回目のデプロイ（YOSSII812001）のReady検知で終了してしまう可能性がある
- 2回目のデプロイ（robbits0802）がReadyになって初めて https://www.usacon-ai.com/ でテスト可能
- `vercel ls` で直近デプロイを確認し、robbits0802のデプロイがReadyであることを確認してからE2Eテストを開始すること

**E2Eテスト開始前の確認手順（本番）:**
```bash
# 直近のProductionデプロイを確認
vercel ls digital-management-consulting-app --yes 2>&1 | head -10
# → robbits0802 ユーザーの Production デプロイが Ready であることを確認
```

### フォールバック: 固定sleep待機（非ブロッキング）

vercel-watchが使えない場合のフォールバック:

```
Bashツール:
  command: "sleep 180 ; echo 'デプロイ待機完了（staging）'"
  run_in_background: true
  timeout: 360000
  description: "stagingデプロイ待機（3分、最大6分タイムアウト）"
```

```
Bashツール:
  command: "sleep 300 ; echo 'デプロイ待機完了（本番）'"
  run_in_background: true
  timeout: 360000
  description: "本番デプロイ待機（5分、最大6分タイムアウト）"
```

**待機中の行動:**
1. バックグラウンドで監視（またはsleep待機）を開始
2. 待機中にレビュー結果の確認、changelog更新、ドキュメント整理等を並行実施
3. Ready検知（ビープ通知）またはsleep完了通知を受け取ったらE2Eテストを開始
4. 6分経過してもタスクが完了しない場合は自動タイムアウト → そのままE2Eテストに進む

### ブロッキング防止ルール（必須）

> **過去に `gh pr checks --watch` や `TaskOutput(block: true)` で長時間ブロックされ、セッションが応答不能になった問題の再発防止。**

| ルール | 説明 |
|--------|------|
| `gh pr checks --watch` はバックグラウンドで実行 | `run_in_background: true` を指定。完了通知を受け取ってから結果を確認する |
| PRマージは `--auto` を使用 | `gh pr merge --squash --auto` で非同期マージ。チェック完了を待たずに次の作業に進む |
| `sleep` 待機は `TaskOutput(block: false)` で確認 | バックグラウンドタスクの完了確認は非ブロッキングで行う |
| 3分以上ブロックする操作は禁止 | すべて `run_in_background: true` で実行すること |

**NG例（ブロッキング）:**
```bash
# メインスレッドがブロックされる
gh pr checks 123 --watch                    # 数分ブロック
TaskOutput(task_id: "xxx", block: true)     # sleep完了までブロック
```

**OK例（非ブロッキング）:**
```bash
# バックグラウンドで実行
Bash(command: "gh pr checks 123 --watch", run_in_background: true)

# 非ブロッキングでチェック
TaskOutput(task_id: "xxx", block: false)

# 自動マージ（チェック完了を待たない）
gh pr merge 123 --squash --auto
```
