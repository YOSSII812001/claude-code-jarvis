---
name: HTTPエラーハンドリングの2層構造
description: HTTPクライアントのエラーは「トランスポート層」と「アプリケーション層」の2パスがある。リカバリロジックは両方をカバーすること。Issue #1459再発の教訓。
type: feedback
---

HTTPクライアントのエラーハンドリングには2つのレイヤーがある。片方だけ修正しても再発する。

**Path A（アプリケーション層）**: サーバーがHTTPレスポンスを返す（504 HTML、502 text等）→ `response.status` が存在 → `UsaconApiError`
**Path B（トランスポート層）**: レスポンスなしで接続断（タイムアウト、connection reset等）→ socket/undici例外 → `UsaconNetworkError`

**Why:** PR #1472 で Path A のみ修正したが、Vercel maxDuration(800s) で関数が kill されると Path B を通り、リカバリが発動しなかった。テスト時に「504 HTMLレスポンス」は検証したが「レスポンスなし接続断」を検証していなかった。

**How to apply:**
- リカバリ/リトライロジックを実装する際は、必ず `instanceof` チェックが **両方のエラー型** をカバーしているか確認
- テスト時に「サーバーがエラーレスポンスを返す」ケースだけでなく「レスポンスなしで接続が切れる」ケースも必ず検証
- undici のタイムアウトエラー（`UND_ERR_HEADERS_TIMEOUT`, `UND_ERR_BODY_TIMEOUT`）は `Error` のサブクラスだが、独自エラー型ではないため catch-all に吸収されやすい
