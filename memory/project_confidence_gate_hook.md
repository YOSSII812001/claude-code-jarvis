---
name: E2E自信ゲートHook
description: E2Eテスト結果報告を検出して自信ゲート(C1-C6)を強制注入するStop Hook
type: project
---

## E2E Confidence Gate Hook

**ファイル**: `C:\Users\zooyo\.claude\confidence_gate_hook.ps1` (351行, UTF-8 BOM)
**設定**: `settings.json` Stop hooks の4番目エントリ (timeout: 15000ms)

### 動作フロー
1. Stop event → last_assistant_message を分析
2. 重み付きスコアリングでE2E報告を検出（閾値≥5）
3. stdout にC1-C6ゲート質問をUTF-8で出力
4. Claude Codeが `user-prompt-submit-hook` として注入 → 回答が強制される

### スコアリング
- **Category A (重み3)**: テスト結果テーブル行, "e2e_result" JSON, confidence_gate JSON
- **Category B (重み2)**: テスト結果/完了/報告, Playwright出力, Phase 3/B+テスト
- **Category C (重み1)**: T1-T5 3回以上, PASS/FAIL 2回以上, E2E 3回以上
- **Negative (-2)**: テスト計画のみ, Phase 1のみ

### Anti-loop
- `[CONFIDENCE GATE]` 検出 → skip
- C1-C6回答パターン3個以上 + evidence_ref 2回以上 → skip
- `confidence_gate_response` マーカー → skip
- クールダウン: 120秒 (`$env:TEMP\claude-confidence-gate-last.txt`)

### 注意事項
- **stdout日本語**: char code構築 → UTF-8バイト直書き（PowerShellのCP932問題回避）
- **stdin**: `[Console]::OpenStandardInput()` + JARVIS共有ファイルフォールバック
- **エラー時**: exit 0（Claudeの動作を妨げない）
- **テストモード**: `-Test` パラメータでスコア確認可能
- **SubagentStop**: 未対応（必要に応じて追加）
