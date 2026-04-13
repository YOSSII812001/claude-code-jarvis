---
name: vercel-watch
description: Vercelデプロイ状況のリアルタイム監視。PR送信後・staging→mainマージ後にデプロイ完了を検知し、E2Eテスト開始タイミングを通知。固定sleep待機の代替として使用。
trigger:
  - "vercel-watch"
  - "デプロイ監視"
  - "デプロイ待機"
  - "deploy watch"
  - "ビルド監視"
  - "デプロイ完了検知"
related:
  - usacon
  - vercel-cli
  - playwright
---

# Vercel Deploy Watcher

## 概要

Vercelデプロイのステータス変更をリアルタイムで検知するスキル。
従来の固定sleep待機（`sleep 180` / `sleep 300`）を置き換え、**実際のビルド完了を検知**して最速でE2Eテストを開始する。

## スクリプト

`C:\Users\zooyo\.claude\scripts\vercel-watch.ps1`

## 使い方

### 1. デプロイ完了まで待機して自動終了（推奨）

```bash
# Building検知後、全デプロイがReady/Error/Canceledになったら自動終了（exit 0/1）
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Preview
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Production
```

**Claude Code内での使用（run_in_background: true と併用）:**
```bash
# TaskOutputでブロックせず、プロセスはReady検知後に自動終了する
Bash(command: 'powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Preview',
     run_in_background: true, timeout: 360000)
```

### 2. 一回だけ現在のデプロイ状況を確認

```bash
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Once
```

### 3. リアルタイム監視（手動終了、Ctrl+C）

```bash
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1"
```

### 4. Productionのみ監視

```bash
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Environment Production
```

### 5. ポーリング間隔変更（5秒）

```bash
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Interval 5
```

### 6. 別プロジェクト

```bash
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Project "other-project"
```

## ステータス表示

| アイコン | ステータス | 意味 |
|---------|-----------|------|
| `[+]` (緑) | Ready | デプロイ成功 |
| `[~]` (黄) | Building | ビルド中 |
| `[x]` (赤) | Error | デプロイ失敗 |
| `[-]` (灰) | Canceled | キャンセル |

## usaconフローへの統合

### PRマージ後のデプロイ監視（staging）

PRをstagingにマージした後、固定sleepの代わりにvercel-watchでビルド完了を監視する。

**従来のフロー（固定sleep）:**
```
gh pr merge --squash → sleep 180 → E2Eテスト
```

**新フロー（vercel-watch -WaitForReady）:**
```
gh pr merge --squash → vercel-watch -WaitForReady（Building検知→Ready→自動exit 0）→ E2Eテスト
```

**実装パターン（非ブロッキング、Ready検知後に自動終了）:**
```bash
# バックグラウンドで監視開始（run_in_background: true, timeout: 360000）
# -WaitForReady により、全Buildingが完了したらプロセスが自動終了する
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Preview -Interval 10

# → プロセス終了（TaskOutput通知）→ E2Eテスト開始
```

### staging→mainマージ後のデプロイ監視（Production）

> **重要: 本番デプロイは2段階構造**（MEMORY.md「Vercel本番デプロイの2段階構造」参照）
> vercel-watch の Ready 検知だけでは不十分。robbits0802 のデプロイ確認が必須。

```bash
# 1. バックグラウンドで監視開始（run_in_background: true, timeout: 360000）
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Production -Interval 10

# 2. TaskOutput通知を受信（Ready検知）

# 3. 2段階デプロイの確認（必須）
# YOSSII812001のデプロイがReady → robbits0802のデプロイがReadyか確認
vercel ls digital-management-consulting-app --yes 2>&1 | head -10
# → robbits0802 ユーザーの Production デプロイが Ready であることを確認
# → robbits0802がまだBuildingの場合、追加で vercel-watch を再実行するか sleep 60 で待機

# 4. 本番確認（E2Eテストまたはスモークテスト）
```

**本番デプロイ監視後の自動継続（必須）:**
vercel-watch Ready検知 → robbits0802確認 → 本番E2E確認 を**途中停止せず**に自動実行すること。
「mainデプロイ完了しました」とユーザーに報告して止まるのは**アンチパターン**。

### Claude Code内での自動監視パターン

PRマージ直後にClaude Codeが自動実行するパターン:

```
1. gh pr merge --squash
2. Bashツール（run_in_background: true, timeout: 360000）:
     powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -WaitForReady -Environment Preview -Interval 10
3. プロセスが自動終了 → TaskOutput通知を受信
4. exit 0 → E2Eテスト開始 / exit 1 → エラー確認
```

**注意:** `-WaitForReady` なしで実行すると無限ループになり、`TaskOutput` がブロックされる。
Claude Code内では必ず `-WaitForReady` を使用すること。

### vercel-watch → 後続タスク自動継続ルール（必須）

> **アンチパターン（禁止）**: vercel-watchをバックグラウンドで起動し、
> ユーザーに「デプロイ完了しました」と報告して止まる。
> ユーザーが「デプロイ完了」と手動で伝えるまで待つ。

**正しいフロー:**
```
vercel-watch Ready検知（TaskOutput通知受信）
  ↓ 自動継続（途中停止禁止）
[Preview] → E2Eテスト開始
[Production] → robbits0802デプロイ確認 → 本番E2Eスモークテスト
```

vercel-watchは**デプロイ完了の検知手段**であり、**パイプラインの終端ではない**。
Ready検知後は必ず後続のE2Eテストに自動遷移すること。

## 変更検知ロジック

| 検知パターン | 通知内容 |
|-------------|---------|
| 初回チェックでBuilding検出 | `[PROD/Preview] ビルド検出` |
| Building → Ready | `[PROD/Preview] デプロイ成功! (Duration)` |
| Building → Error | `[PROD/Preview] デプロイ失敗!` |
| 新しいURL出現 | `[PROD/Preview] 新規デプロイ開始` |
| Building → Canceled | `[PROD/Preview] デプロイキャンセル` |

Productionの変更は常にPreviewより優先表示される。

## トラブルシューティング

### パースに失敗する

Vercel CLIの `●` 文字はUTF-8マルチバイトで、PowerShellのエンコーディング設定により壊れることがある。
スクリプトは `\s{2,}` での空白分割 + 既知ステータス名のマッチングでこの問題を回避済み。

### デプロイが検知されない

```bash
# まず手動でvercel lsを確認
vercel ls digital-management-consulting-app
```

Vercelプロジェクトにリンクされていない場合:
```bash
cd <project-dir> && vercel link
```

### タイムアウト

`-WaitForReady` なしのデフォルト監視は無限ループ。Claude Code内では必ず `-WaitForReady` を使用すること。
加えて、安全策として `timeout: 360000`（6分）を設定し、万が一の無限待機を防ぐこと。

### TaskOutputがブロックされる

`-WaitForReady` なしで `run_in_background: true` を使用すると、プロセスが終了しないため `TaskOutput` が永久にブロックされる。
**解決:** 必ず `-WaitForReady` フラグを付けて実行すること。

### Continuousモードで通知が来ない

Continuousモード（`-WaitForReady` なし）をバックグラウンド実行（`run_in_background: true`）すると、プロセスが終了しないため完了通知（TaskOutput）が配信されない。

| ステップ | よくある問題 | 解決方法 |
|---------|-------------|---------|
| バックグラウンド実行 | Continuousモードで通知が来ない | `-WaitForReady` モードを使用する。Continuousモードは終了しないためバックグラウンドタスクの完了通知が配信されない |
| 2段階デプロイ | 1回目のReady検知で終了してしまう | `vercel ls` で robbits0802 の Production デプロイが Ready か手動確認 |

## チェックリスト

- [ ] 適切なモード（-WaitForReady / Continuous）を選択したか
- [ ] 本番デプロイの場合、2段階デプロイを考慮したか
- [ ] `timeout` パラメータを設定したか（推奨: 360000ms）
- [ ] `run_in_background: true` を指定したか

## 関連スキル

| スキル | 関連 |
|--------|------|
| `usacon` | デプロイ監視の実プロジェクト |
| `vercel-cli` | Vercel CLI操作全般 |
| `e2e-test` | デプロイ完了後のE2Eテスト連携 |

---

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-03 | Production監視に2段階デプロイ確認手順を追加、自動継続ルール明記、バッチパイプライン連携セクション追加 | PR #1107マージ後にvercel-watchをバックグラウンド起動したがパイプラインが停止し、ユーザーが手動で「mainデプロイ完了」を伝えるまで止まっていた教訓 |
| 2026-03-04 | Continuousモード通知未配信のトラブルシューティング追加、チェックリスト・関連スキル追加 | 教訓#7統合（Continuousモードバックグラウンド実行で通知未配信）+ スキル品質改善 |
