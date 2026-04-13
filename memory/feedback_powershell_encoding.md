---
name: PowerShell script encoding and API lessons
description: PS1のBOM/param/winmm罠、日本語char code化、固定一時ファイル名のGUID化、voiceEnabledの正体
type: feedback
---

PowerShellスクリプト作成時の罠と対策:

## 1. UTF-8 BOM必須
Claude CodeのWriteツールはBOMなしUTF-8で保存する。PowerShell 5.1/7は日本語入りPS1ファイルをBOMなしだと化ける。Write後に必ずBOM付与:
```powershell
[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($true)))
```

## 2. param()は最初のステートメント
コメント以外のコード（`[Console]::OutputEncoding = ...`等）をparam()の前に置くとParseError。エンコーディング設定はparam()の後に。

## 3. System.Mediaアセンブリ不在
PowerShell 7 (.NET Core) では `Add-Type -AssemblyName System.Media` が失敗する。WAV再生はwinmm.dll PlaySound一択:
```powershell
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class WavPlayer {
    [DllImport("winmm.dll")] public static extern bool PlaySound(string s, IntPtr h, uint f);
}
"@ -ErrorAction SilentlyContinue
[WavPlayer]::PlaySound($wavPath, [IntPtr]::Zero, 0x00020000)
```

## 4. 日本語リテラルはchar codeで回避
BOM付きでも `'。'` `'、'` が壊れるケースがある（heredoc経由等）。安全策として `[char]0x3002`（。）`[char]0x3001`（、）を使えばBOM依存を完全回避。

## 5. 固定一時ファイル名は残留バグの温床
`jarvis_speech.wav` のような固定名だと、前回のファイルが残留し次回に古い内容を再生してしまう。**必ずGUID付きファイル名にする**:
```powershell
$runId = [guid]::NewGuid().ToString("N").Substring(0, 8)
$wavPath = Join-Path $env:TEMP "jarvis_speech_$runId.wav"
```
実行後は古いファイルをクリーンアップ（`Get-ChildItem -Filter "jarvis_speech_*.wav" | Where { $_.Name -notmatch $runId } | Remove-Item`）。

## 6. voiceEnabledはTTSではない
Claude Codeの `voiceEnabled: true` は**音声入力（ディクテーション）**機能。TTS出力は含まない。音声二重再生の原因としてvoiceEnabledを疑うのは誤診断。

**Why:** PS5.1とPS7が混在するWindows環境で、どちらでも動くスクリプトを書く必要があるため。固定ファイル名バグはCodex分析で特定。
**How to apply:** PS1新規作成時にBOM変換。日本語はchar code。一時ファイルはGUID付き。voiceEnabledを音声出力と混同しない。
