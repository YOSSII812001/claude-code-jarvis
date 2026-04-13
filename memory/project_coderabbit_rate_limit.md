---
name: CodeRabbit レートリミット問題
description: バッチ実装で複数PR短時間作成時にCodeRabbitのレートリミットに抵触する問題。回避策を実装済み。
type: project
---

CodeRabbitがバッチ実装中のPRレビューでレートリミットに遭遇（PR #1525、2026-03-19）。10分29秒の待機が発生。

**Status:** 対策実装済み（2026-03-27）

**Why:** issue-autopilot-batchで5件のPRを短時間に連続作成すると、CodeRabbitのAPI呼び出し制限に抵触する。

**Implemented mitigation:**
- Step 7b直後に `7b-post. CodeRabbitレビュー確認` ステップを追加
- `gh pr checks --watch` でCodeRabbit完了待ちを標準フローに組み込み
- セキュリティ/バグ指摘は hard block（解消前staging merge禁止）
- `coderabbit_status` フィールド（PASS / FIXED / TECH_DEBT / SKIPPED）で状態ファイルに記録
- Step 7g のクールダウンを30秒→60秒に延長（レート制限回避）
- 核心ルール15、ガードレールB18、アンチパターン#29として体系化

**How to apply:**
- Step 7b-post のCodeRabbit確認をスキップしない
- `coderabbit_status` 未確定/セキュリティ・バグ指摘未解消のPRはstaging mergeしない
- 次のPR作成前に最低60秒のインターバルを確保
- Step 8.7は「最終確認（漏れチェック）」に役割変更済み（メイン処理はStep 7b-postで完了）
