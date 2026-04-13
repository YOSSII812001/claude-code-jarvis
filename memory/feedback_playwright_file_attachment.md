---
name: Playwright MCPのファイルDL/UL制約と代替手段
description: Playwright MCPブラウザではファイル添付・ダウンロード操作が不可。fetch()代替やplaywright-cli run-codeで回避可能
type: feedback
---

Playwright MCPブラウザではファイル添付（input[type="file"]）とファイルダウンロード（Blob URL + OS保存）が操作できない。

**Why:** #1641（添付不可）と#1669（DL不可でSKIP→本番バグ見逃し）で発覚。SKIPし続けるとExcelエクスポート等のバグが本番まで残る。

**How to apply:**
- **添付（UL）**: ユーザー手動確認に委任、`browser_boundary` として報告に記載
- **ダウンロード（DL）**: `browser_evaluate` 内で `fetch(apiUrl)` → ステータスコード・Content-Type・レスポンスサイズを検証（SKIPせず必ず実施）
- **CLIの代替**: `playwright-cli run-code` で `waitForEvent('download')` + `saveAs()` がより確実
- 添付以外の項目はPlaywrightで自動テスト可
