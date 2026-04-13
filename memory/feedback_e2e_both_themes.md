---
name: E2Eテストは両テーマで実施
description: UI/テーマ関連IssueではNordLight+Cyberpunk両テーマでE2E確認必須
type: feedback
originSessionId: 0600808d-9b4d-4b44-b802-565f3fb13d45
---
UI/テーマ変更を含むIssueのE2Eテストでは、NordLightとCyberpunkの両テーマで確認する。

**Why:** Issue #1764のE2EでNordLightのみ確認して完了扱いにした。ユーザーから「サイバーテーマでも同じようにチェックして」と指摘。DynamicThemeProviderへの変更はCyberpunkにも影響するため片方だけでは不十分。

**How to apply:** E2Eテスト計画作成時、変更ファイルにテーマ関連（nord-theme.ts, DynamicThemeProvider.tsx, *-theme.css）が含まれる場合、両テーマでの画面確認を計画に入れる。
