---
name: パイプライン完了の定義
description: mainマージ後も本番デプロイ確認まで自動継続。途中停止禁止の徹底
type: feedback
originSessionId: 0600808d-9b4d-4b44-b802-565f3fb13d45
---
mainマージ後に「デプロイ待ち」で停止してはならない。本番E2E確認まで自動継続する。

**Why:** Issue #1764引き継ぎ時、staging→main PRマージ後に「完了サマリー」を提示して停止した。ユーザーから「なんで止まってるの？」と指摘された。

**How to apply:** staging→main マージ後は、vercel-watch or 手動で本番デプロイ完了を確認し、usacon-ai.comでの表示確認まで自動継続する。完了サマリーはその後に出す。
