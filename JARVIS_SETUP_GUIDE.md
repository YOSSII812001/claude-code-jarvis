# JARVIS Voice System for Claude Code - Setup Guide

Claude Codeの応答をJARVIS風のデジタル音声でリアルタイム読み上げするシステムです。

## 動作環境

- Windows 10 / 11
- Claude Code CLI
- PowerShell 5.1+ または 7+

## 必要なソフトウェア

| ソフトウェア | 用途 | インストール方法 |
|-------------|------|-----------------|
| VOICEVOX | 音声合成エンジン | https://voicevox.hiroshiba.jp/ からダウンロード |
| FFmpeg | 音声デジタル加工 | `winget install --id Gyan.FFmpeg -e` |

## セットアップ手順

### Step 1: VOICEVOX インストール

1. https://voicevox.hiroshiba.jp/ からインストーラーをダウンロード
2. インストール実行（デフォルト設定でOK）
3. 一度起動して、エンジンが `http://127.0.0.1:50021` で動作することを確認

### Step 2: FFmpeg インストール

PowerShellまたはコマンドプロンプトで実行：

```powershell
winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
```

インストール後、シェルを再起動してPATHを反映。

### Step 3: スクリプト配置

以下の2ファイルを `~/.claude/` (= `C:\Users\<username>\.claude\`) にコピー：

- `speak_jarvis.ps1` - メインHookスクリプト
- `test_jarvis.ps1` - テスト・パラメータ調整用

### Step 4: UTF-8 BOM 変換（重要）

PowerShellで実行して、スクリプトをUTF-8 BOM付きに変換します：

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
foreach ($f in @("$HOME\.claude\speak_jarvis.ps1", "$HOME\.claude\test_jarvis.ps1")) {
    $c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($f, $c, $utf8Bom)
}
Write-Host "BOM conversion complete"
```

> **Why?** Claude CodeのWriteツールはBOMなしUTF-8で保存しますが、PowerShell 5.1は
> BOMなしだと日本語を正しく読めません。この変換を忘れるとスクリプトがパースエラーになります。

### Step 5: settings.json 設定

`~/.claude/settings.json` の `hooks` セクションに以下を追加（既存のStop hookがあれば置き換え）：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\<username>\\.claude\\speak_jarvis.ps1\"",
            "timeout": 15000
          }
        ]
      }
    ]
  }
}
```

`<username>` を自分のWindowsユーザー名に置き換えてください。

### Step 6: VOICEVOX 自動起動設定（任意）

PC起動時にVOICEVOXを自動起動させたい場合、PowerShellで実行：

```powershell
$WshShell = New-Object -ComObject WScript.Shell
$startupPath = [Environment]::GetFolderPath('Startup')
$shortcut = $WshShell.CreateShortcut("$startupPath\VOICEVOX.lnk")
$shortcut.TargetPath = "C:\Program Files\VOICEVOX\VOICEVOX.exe"
$shortcut.WorkingDirectory = "C:\Program Files\VOICEVOX"
$shortcut.WindowStyle = 7  # Minimized
$shortcut.Save()
Write-Host "Startup shortcut created"
```

> VOICEVOXのインストール先が異なる場合は `TargetPath` を調整してください。

### Step 7: テスト

VOICEVOXを起動した状態で：

```powershell
# 基本テスト（接続確認 + サンプル発話）
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\test_jarvis.ps1"

# 話者一覧を確認
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\test_jarvis.ps1" -ListSpeakers

# パラメータ調整（対話的）
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\test_jarvis.ps1" -Tune
```

全テストが合格すれば、次のClaude Code応答からJARVIS声で自動読み上げされます。

## 仕組み

```
Claude Codeが応答完了
  ↓
Stop Hook が speak_jarvis.ps1 を起動（Hook Mode）
  ↓
stdin から JSON を読み取り → last_assistant_message を抽出
  ↓
Markdownを除去 → 200文字に切り詰め → テキストをtempファイルに保存
  ↓
バックグラウンドで Worker プロセスを起動 → Hook は即 return（Claudeをブロックしない）
  ↓
Worker: VOICEVOX API で音声合成 → FFmpeg でデジタルエフェクト適用 → 再生
```

## カスタマイズ

### 声の変更

`speak_jarvis.ps1` の `param()` ブロックでデフォルト値を変更：

```powershell
param(
    [int]$SpeakerId = 21,         # 話者ID（test_jarvis.ps1 -ListSpeakers で確認）
    [double]$SpeedScale = 0.92,    # 話速（0.5-2.0、小さい=ゆっくり）
    [double]$PitchScale = -0.1,    # 音高（-0.15〜0.15、小さい=低い）
    [double]$IntonationScale = 0.8, # 抑揚（0.0-2.0、小さい=棒読み）
    [double]$VolumeScale = 1.5,    # 音量（0.0-2.0）
    [int]$MaxLength = 200,         # 最大読み上げ文字数
)
```

### FFmpegフィルターの変更

`speak_jarvis.ps1` 内の `$ffmpegFilter` を編集：

```powershell
# デフォルト（控えめな空間リバーブ）
$ffmpegFilter = "highpass=f=180,lowpass=f=5500,aecho=0.8:0.88:15|30:0.3|0.15,equalizer=f=1200:width_type=o:width=2:g=2"

# より機械的にしたい場合
$ffmpegFilter = "highpass=f=300,lowpass=f=4500,aecho=0.8:0.85:8:0.5,flanger=delay=2:depth=1:speed=0.3,equalizer=f=1400:width_type=o:width=2:g=4"

# エフェクトなし（VOICEVOX素の声）
$ffmpegFilter = ""
```

| フィルター | 効果 |
|-----------|------|
| `highpass=f=180` | 低音カット（スピーカー越し感） |
| `lowpass=f=5500` | 高音カット（デジタルフィルター感） |
| `aecho=0.8:0.88:15\|30:0.3\|0.15` | 空間リバーブ（ラボ反響） |
| `equalizer=f=1200:...` | 中音域ブースト（明瞭さ） |
| `flanger` | 電子的な揺らぎ（強めのデジタル感） |
| `vibrato` | ケロケロボイス |
| `asetrate=48000*1.15` | ピッチシフト |

### 読み上げ文字数の変更

長い応答を全部読ませたい場合は `MaxLength` を増やす：

```powershell
[int]$MaxLength = 500,  # 500文字まで読み上げ
```

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| 音声が出ない | VOICEVOXが起動していない | VOICEVOXアプリを起動する |
| 音声が出ない | FFmpegが見つからない | `winget install Gyan.FFmpeg` → シェル再起動 |
| パースエラーが出る | BOMなしUTF-8 | Step 4のBOM変換を再実行 |
| `param()` でエラー | param()の前にコードがある | param()はスクリプト最初のステートメントにする |
| Hook自体が動かない | settings.jsonのパスが間違い | `<username>` を確認 |
| JSON解析エラー | stdin が UTF-8 でない | `[Console]::InputEncoding = UTF8` が入っているか確認 |
| ビープ音だけ鳴る | VOICEVOX未起動時のフォールバック | VOICEVOXを起動する |
| 音声が遅延する | 長いテキストの合成に時間がかかる | `MaxLength` を小さくする |

### デバッグモード

問題が起きた場合、settings.jsonのcommandに `-Debug` を追加：

```json
"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"...\\speak_jarvis.ps1\" -Debug"
```

デバッグログが `%TEMP%\jarvis_debug.log` に出力されます。

## 技術的な注意点

- **PowerShell BOM問題**: PS1ファイルは必ずUTF-8 BOM付きで保存する
- **System.Media不在**: PowerShell 7では `System.Media.SoundPlayer` が使えない。`winmm.dll` の `PlaySound` をP/Invokeで使用
- **stdin エンコーディング**: Claude Code HookはUTF-8でJSONを渡すが、PowerShellのデフォルトはShift-JIS。`[Console]::InputEncoding = UTF8` が必須
- **バックグラウンド再生**: Hook本体は即returnし、音声合成+再生はバックグラウンドプロセスで実行（Claudeの応答をブロックしない）
