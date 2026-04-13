---
name: codex-plugin-test-results
description: Codexプラグイン(v1.0.1)のテスト結果、Windows互換性バグ修正、カスタムスキルとの共存方針
type: project
---

## Codexプラグイン テスト結果 (2026-03-31)

### 環境
- プラグイン: `codex@openai-codex` v1.0.1 (GitHub: openai/codex-plugin-cc)
- Codex CLI: `@openai/codex@0.115.0`
- インストール先: `C:\Users\zooyo\.claude\plugins\marketplaces\openai-codex\plugins\codex\`

### Windows互換性バグ（修正済み）
- **原因**: `lib/app-server.mjs:188` の `spawn("codex", ["app-server"])` に `shell: true` がない
- **症状**: 全てのcompanion経由ジョブ（task/review/adversarial-review）がENOENTで失敗
- **修正**: `shell: process.platform === "win32"` を追加（ローカル修正）
- **影響範囲**: setup/status/result/cancelは `runCommand` (shell対応済み) を使うため影響なし
- **注意**: プラグイン更新時に上書きされる可能性あり。更新後に再修正が必要

**Why:** プラグインはMac/Linux前提で開発されており、Windowsの.cmd shim問題が未対処
**How to apply:** プラグイン更新後に `app-server.mjs:188` の `shell` オプション確認

### カスタムスキルとの共存方針
- **カスタム`codex`維持**: final-check(ガードレール付き), エスカレーション基準, 9個の依存スキル向けexecパターン
- **カスタム`codex-autopilot`維持**: 自律意思決定パターンはプラグインに対応機能なし
- **プラグイン採用**: review/adversarial-review(構造化出力), setup(環境チェック), status/result/cancel(ジョブ管理)
- **gpt-5-4-prompting取り込み**: XMLブロック構造をカスタムスキルのプロンプト品質向上に活用

### 依存スキル（9個）
issue-planner, security-adversarial, issue-flow, usacon, detail-design-doc, issue-autopilot-batch, design-review-checklist, codex, codex-autopilot
