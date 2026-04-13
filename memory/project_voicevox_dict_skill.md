---
name: VOICEVOX辞書管理スキル
description: voicevox-dictスキルの作成記録とVOICEVOX辞書API利用時の既知の制約
type: project
---

## voicevox-dict スキル（2026-03-26作成）

### 概要
- スキルパス: `~/.claude/skills/voicevox-dict/`
- ファイル: `SKILL.md` + `voicevox-dict-helper.ps1`（BOM付きUTF-8）
- スターター辞書: IT用語66語（Register動作確認済み）

### 既知の制約: GET /user_dict のエンコーディング問題

**Why:** VOICEVOX Engine の GET /user_dict API は、surfaceを内部形式（カタカナ半角等）で返す。PowerShell 5.1 の `Invoke-RestMethod`/`WebClient`/`DownloadData` + `UTF8.GetString` いずれでもsurface値が文字化け → 冪等チェック・Search・Backupが不完全。

**How to apply:**
- BulkRegisterは「既存チェックなしで毎回登録」として運用（VOICEVOX APIが重複を許容するため実害なし）
- Search/Backupは将来改善（VOICEVOX GUIでの確認を併用）
- 辞書の初回登録（66語）は正常に動作、audio_queryでの発音反映も確認済み
- 今後の改善候補: PowerShell 7 (pwsh) での `Invoke-RestMethod -ResponseHeadersVariable` 活用

### BOM変換手順
Edit後に必ず BOM再変換が必要:
```powershell
$content = Get-Content -Path "$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1" -Raw -Encoding utf8
[System.IO.File]::WriteAllText("$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1", $content, [System.Text.UTF8Encoding]::new($true))
```
