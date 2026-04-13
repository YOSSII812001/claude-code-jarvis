---
name: Usacon自律駆動化プロジェクト
description: Heartbeat基盤によるUsaconの自律駆動化。Fortress Review完了→9 Issue起票済み。issue-planner待ち。
type: project
originSessionId: 5315b719-0b83-4372-820d-41725c25079a
---
## 状態（2026-04-09）

計画策定 → Fortress Review(Tier A, No-Go) → 再設計 → 9 Issue起票 完了。次は issue-planner。

## Issue一覧（#1775〜#1783）

- **#1775** DBスキーマ基盤 [M] — 全Issueの起点
- **#1776** Cron認証+Dispatcher [M] — CRON_SECRET共通化、claim/leaseパターン
- **#1777** Signal Scan Worker [L] — RSS/API + Haiku XMLタグ構造化プロンプト
- **#1778** Pipeline Handoff [L] ★CRITICAL対応 — 1Step=1Function、fire-and-forget
- **#1779** 通知システム [M] — 1日10件上限、priority/score/dedupe_key
- **#1780** ダッシュボード統合 [L] — チャット/レポート/ProcessTypeマッピング
- **#1781** 運用基盤 [M] — Cleanup Cron、content-hash cache
- **#1782** セキュリティ強化 [S] — 環境変数移行、promptSanitizer
- **#1783** 今日の問い [S] — executive_question_catalogから日替わり提示

## クリティカルパス

#1775 → #1776 → #1777 → #1778 → #1779 → #1780

## 主要設計判断

- AIモデル: Haiku（クレジット消費なし）
- CRONは実行器ではなくwatchdog（番犬）
- analysis_pipelineはHandoffパターン（チェーン実行禁止）
- analysis_runsに書き戻し（既存チャット/ダッシュ/レポート統合）
- step_key = ProcessType (P1-1/P1-2/P2-CSF/P2-Strategy)

## 引き継ぎ書

`Obsidian Vault/株式会社Robbits/Saas/Usacon/Usacon自律化/引き継ぎ書_2026-04-09.md`
