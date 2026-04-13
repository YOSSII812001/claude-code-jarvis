# Style-Bert-VITS2 + ずんだもんボイス 導入手順

> **このドキュメントは [`SKILL.md`](./SKILL.md) の補助ファイルです。**
> スキルの有効化/無効化やAPI仕様の詳細は SKILL.md を参照してください。

---

## 目次

1. [前提条件](#1-前提条件)
2. [インストール手順](#2-インストール手順)
3. [ずんだもんモデルの入手と配置](#3-ずんだもんモデルの入手と配置)
4. [config.yml 設定](#4-configyml-設定)
5. [APIサーバー起動](#5-apiサーバー起動)
6. [動作テスト](#6-動作テスト)
7. [スキルとの連携](#7-スキルとの連携)
8. [トラブルシューティング](#8-トラブルシューティング)

---

## 1. 前提条件

| 項目 | 要件 | 備考 |
|------|------|------|
| **Python** | 3.11.x | 3.13はtorch<2.4と非互換のためNG。`py -3.11 --version` で確認 |
| **NVIDIA GPU** | RTX 30xx以降推奨 | VRAM 8GB以上。本環境: RTX 4070 Ti SUPER (16GB) |
| **CUDA** | 12.1 | `nvidia-smi` でバージョン確認。CUDA Toolkit不要（PyTorchに同梱） |
| **FFmpeg** | 最新安定版 | JARVIS風エフェクト適用に必須。`ffmpeg -version` で確認 |
| **git** | 最新版 | リポジトリクローンに使用 |

### 前提条件の確認コマンド

```powershell
# Python 3.11 確認
py -3.11 --version

# NVIDIA GPU & CUDA 確認
nvidia-smi

# FFmpeg 確認
ffmpeg -version

# git 確認
git --version
```

### FFmpegが未インストールの場合

```powershell
winget install Gyan.FFmpeg
```

インストール後、**新しいターミナルを開き直す**か、以下でPATHを再読み込み:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
```

---

## 2. インストール手順

### 2-1. リポジトリのクローン

```powershell
git clone https://github.com/litagin02/Style-Bert-VITS2.git C:\Users\zooyo\Style-Bert-VITS2
```

### 2-2. Python仮想環境の作成

```powershell
py -3.11 -m venv C:\Users\zooyo\Style-Bert-VITS2\venv
```

### 2-3. PyTorch（CUDA 12.1対応版）のインストール

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\pip.exe install torch==2.3.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121
```

> **重要**: PyTorchを先にインストールすること。requirements.txtが先だとCPU版がインストールされてしまう場合がある。

### 2-4. 依存パッケージのインストール

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\pip.exe install -r C:\Users\zooyo\Style-Bert-VITS2\requirements.txt
```

### 2-5. インストール確認

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe -c "import torch; print(f'PyTorch {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
```

期待される出力:
```
PyTorch 2.3.1+cu121
CUDA available: True
GPU: NVIDIA GeForce RTX 4070 Ti SUPER
```

---

## 3. ずんだもんモデルの入手と配置

### 3-1. モデルのダウンロード

Hugging Faceで「Style-Bert-VITS2 zundamon」を検索し、学習済みモデルをダウンロードする。

代表的な配布元:
- Hugging Face: `https://huggingface.co/` で「Style-Bert-VITS2 zundamon」を検索
- 東北ずん子プロジェクト公式から音声データを取得して自前学習も可能

### 3-2. ファイル配置

ダウンロードしたファイルを `model_assets/zundamon/` 配下に配置する。

```
C:\Users\zooyo\Style-Bert-VITS2\
  model_assets\
    zundamon\
      config.json            ... モデル設定ファイル
      zundamon_e100_s5000.safetensors  ... モデルウェイト（ファイル名は配布元による）
      style_vectors.npy      ... スタイルベクトル
```

### 3-3. 配置の確認

```powershell
Get-ChildItem -Path "C:\Users\zooyo\Style-Bert-VITS2\model_assets\zundamon" -Recurse | Format-Table Name, Length, LastWriteTime
```

以下の3種類のファイルが存在することを確認:
- `config.json` -- モデルのアーキテクチャ設定
- `*.safetensors` または `*.pth` -- モデルの重みファイル（数百MB～数GB）
- `style_vectors.npy` -- 感情・スタイル制御用ベクトル

> **注意**: `config.json` の `data.training_files` パスがローカル環境と合わない場合があるが、推論（APIサーバー起動）には影響しない。

---

## 4. config.yml 設定

### 4-1. 設定ファイルの編集

`C:\Users\zooyo\Style-Bert-VITS2\config.yml` を以下のように設定する:

```yaml
server:
  port: 5000
  device: "cuda"
  limit: 300
```

### 4-2. 各パラメータの説明

| パラメータ | デフォルト | 推奨値 | 説明 |
|-----------|-----------|--------|------|
| `port` | 5000 | 5000 | APIサーバーのリッスンポート。speak_zundamon.ps1のデフォルト設定と合わせる |
| `device` | "cuda" | "cuda" | 推論デバイス。GPUがない場合は`"cpu"`（大幅に遅延） |
| `limit` | 100 | **300** | 1リクエストあたりの最大文字数 |

### なぜ limit を300に拡張するのか

- Style-Bert-VITS2のデフォルトは**100文字**だが、Claudeの応答は長文になることが多い
- `speak_zundamon.ps1` はMarkdown除去後のテキストを最大250文字（`-MaxLength`パラメータ）に切り詰めるが、マルチバイト文字のエンコーディングで超過する場合がある
- **300文字**に設定しておくことで、API側での切り捨てを防止し、スクリプト側の制御に委ねる

### 4-3. config.yml が存在しない場合

リポジトリに `config.yml` のテンプレートが含まれていない場合は、新規作成する:

```powershell
@"
server:
  port: 5000
  device: "cuda"
  limit: 300
"@ | Set-Content -Path "C:\Users\zooyo\Style-Bert-VITS2\config.yml" -Encoding utf8NoBOM
```

---

## 5. APIサーバー起動

### 5-1. 手動起動

```powershell
Set-Location C:\Users\zooyo\Style-Bert-VITS2
.\venv\Scripts\python.exe server_fastapi.py
```

サーバーが正常に起動すると、以下のようなログが表示される:

```
INFO:     Uvicorn running on http://0.0.0.0:5000 (Press CTRL+C to stop)
```

### 5-2. 起動確認

#### Swagger UI

ブラウザで `http://127.0.0.1:5000/docs` を開き、FastAPIのSwagger UIが表示されればOK。

#### モデル情報の確認

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:5000/models/info" | ConvertTo-Json -Depth 5
```

ずんだもんモデルがロードされていれば、レスポンスに `zundamon` のエントリが含まれる。

### 5-3. Windows起動時の自動起動設定

#### 方法A: Startupフォルダにショートカットを配置（推奨）

```powershell
# 起動用バッチファイルを作成
@"
@echo off
cd /d C:\Users\zooyo\Style-Bert-VITS2
call venv\Scripts\activate.bat
python server_fastapi.py
"@ | Set-Content -Path "C:\Users\zooyo\Style-Bert-VITS2\start_server.bat" -Encoding ascii

# Startupフォルダにショートカットを作成
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\SBV2-Server.lnk")
$Shortcut.TargetPath = "C:\Users\zooyo\Style-Bert-VITS2\start_server.bat"
$Shortcut.WorkingDirectory = "C:\Users\zooyo\Style-Bert-VITS2"
$Shortcut.WindowStyle = 7  # 最小化起動
$Shortcut.Save()
```

#### 方法B: タスクスケジューラ（ログオン時に実行）

```powershell
$action = New-ScheduledTaskAction `
    -Execute "C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe" `
    -Argument "server_fastapi.py" `
    -WorkingDirectory "C:\Users\zooyo\Style-Bert-VITS2"

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # 無制限

Register-ScheduledTask `
    -TaskName "Style-Bert-VITS2 Server" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Style-Bert-VITS2 APIサーバー（ずんだもんTTS用）"
```

#### 自動起動の動作確認

```powershell
# タスクスケジューラの場合: 手動トリガーでテスト
Start-ScheduledTask -TaskName "Style-Bert-VITS2 Server"

# 5秒待ってからAPIを叩いてみる
Start-Sleep -Seconds 5
try {
    $info = Invoke-RestMethod -Uri "http://127.0.0.1:5000/models/info" -TimeoutSec 5
    Write-Host "APIサーバー起動成功: $($info | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    Write-Host "APIサーバーに接続できません。起動ログを確認してください。" -ForegroundColor Red
}
```

---

## 6. 動作テスト

### 6-1. PowerShellでの音声合成テスト

APIサーバーが起動していることを前提に、直接音声合成をテストする:

```powershell
# テスト用パラメータ
$params = @{
    text         = "こんにちは、ずんだもんなのだ。今日もいい天気なのだ。"
    speaker_name = "zundamon"
    language     = "JP"
    sdp_ratio    = 0.2
    length       = 1.0
}

# クエリ文字列を構築
$queryString = ($params.GetEnumerator() | ForEach-Object {
    "$($_.Key)=$([uri]::EscapeDataString($_.Value))"
}) -join "&"

# 音声合成リクエスト
$testWav = Join-Path $env:TEMP "zundamon_setup_test.wav"
Invoke-WebRequest -Uri "http://127.0.0.1:5000/voice?$queryString" -Method Post -OutFile $testWav

# ファイルサイズ確認
$fileInfo = Get-Item $testWav
Write-Host "生成されたWAV: $($fileInfo.Length) bytes"

# 再生
Start-Process $testWav
```

正常に動作すれば、ずんだもんの声で「こんにちは、ずんだもんなのだ。今日もいい天気なのだ。」が再生される。

### 6-2. FFmpegエフェクト適用テスト

JARVIS風デジタルエフェクトが適用されることを確認:

```powershell
$testWav = Join-Path $env:TEMP "zundamon_setup_test.wav"
$processedWav = Join-Path $env:TEMP "zundamon_setup_test_fx.wav"

# JARVIS風フィルター（speak_zundamon.ps1と同一）
$filter = "adelay=250|250,highpass=f=220,lowpass=f=4000,aecho=0.8:0.85:15|25|40:0.22|0.14|0.08,aphaser=in_gain=0.9:out_gain=0.9:delay=1.8:decay=0.10:speed=0.5:type=t,chorus=0.96:0.98:8|12:0.02|0.01:0.2|0.25:0.5|0.4,equalizer=f=1200:width_type=o:width=2:g=2,equalizer=f=3200:width_type=o:width=1.5:g=1.5,equalizer=f=5500:width_type=o:width=2:g=0,volume=1.6,apad=pad_dur=0.3"

ffmpeg -nostdin -y -i $testWav -af $filter $processedWav

# エフェクト適用後のファイルを再生
Start-Process $processedWav
```

### 6-3. speak_zundamon.ps1 の単体テスト

実際のHookと同じ形式のJSONを標準入力で渡してテスト:

```powershell
# まずフラグファイルを作成（ずんだもんTTSを有効化）
"active" | Set-Content -Path (Join-Path $env:TEMP "zundamon_tts_active.txt") -Encoding ascii

# テスト用JSON（Claude Code Hookが渡す形式と同じ）
$testJson = @{
    last_assistant_message = "テストメッセージなのだ。ずんだもんの音声が正しく再生されれば、セットアップは完了なのだ。"
} | ConvertTo-Json

# speak_zundamon.ps1 にパイプで渡す（-Debug付きでログ出力）
$testJson | powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\zooyo\.claude\speak_zundamon.ps1" -Debug

# デバッグログを確認
Get-Content (Join-Path $env:TEMP "zundamon_debug.log") -Tail 20
```

全フェーズが `=== speak_zundamon complete ===` で終了していれば成功。

---

## 7. スキルとの連携

### 7-1. 有効化/無効化

Claude Code上で以下のコマンドを使用:

| コマンド | 動作 |
|---------|------|
| `/zundamon-tts` または `/zundamon-tts on` | ずんだもんTTSを有効化。JARVISを自動停止 |
| `/zundamon-tts off` | ずんだもんTTSを無効化。JARVISを復帰 |

### 7-2. フラグファイルによる排他制御

ずんだもんTTSの有効/無効はフラグファイルで管理される:

```
%TEMP%\zundamon_tts_active.txt
```

- **ファイルが存在する** -- ずんだもんTTSが有効
- **ファイルが存在しない** -- JARVISが有効（デフォルト）

### 7-3. JARVIS音声との排他制御の仕組み

```
Claude Code Stop Hook（settings.json）
  |
  +-- speak_jarvis.ps1 起動
  |     |
  |     +-- zundamon_tts_active.txt が存在？
  |           YES -> 即座に exit 0（JARVISスキップ）
  |           NO  -> VOICEVOX音声合成 -> JARVIS風再生
  |
  +-- speak_zundamon.ps1 起動
        |
        +-- zundamon_tts_active.txt が存在？
              YES -> Style-Bert-VITS2音声合成 -> JARVIS風エフェクト -> 再生
              NO  -> 即座に exit 0（ずんだもんスキップ）
```

両スクリプトは同時にHookから起動されるが、フラグファイルの有無で**片方だけが実際に音声合成を実行**する。Mutexによる同時実行防止も各スクリプトに内蔵されている。

### 7-4. 手動でのフラグ操作

```powershell
# 有効化
"active" | Set-Content -Path (Join-Path $env:TEMP "zundamon_tts_active.txt") -Encoding ascii

# 無効化
Remove-Item -Path (Join-Path $env:TEMP "zundamon_tts_active.txt") -Force -ErrorAction SilentlyContinue

# 状態確認
if (Test-Path (Join-Path $env:TEMP "zundamon_tts_active.txt")) {
    Write-Host "ずんだもんTTS: 有効" -ForegroundColor Green
} else {
    Write-Host "ずんだもんTTS: 無効（JARVIS有効）" -ForegroundColor Yellow
}
```

---

## 8. トラブルシューティング

### 8-1. CUDA未検出

**症状**: `torch.cuda.is_available()` が `False` を返す

```powershell
# 確認コマンド
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe -c "import torch; print(torch.cuda.is_available()); print(torch.version.cuda)"
```

**対処法**:
1. NVIDIAドライバが最新か確認: `nvidia-smi`
2. PyTorchがCUDA版か確認: `torch.version.cuda` が `12.1` であること
3. CPU版がインストールされている場合は再インストール:

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\pip.exe uninstall torch torchaudio -y
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\pip.exe install torch==2.3.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121
```

### 8-2. GPU VRAMオーバーフロー（メモリ不足）

**症状**: `torch.cuda.OutOfMemoryError` または `CUDA out of memory`

**対処法**:
1. 他のGPUを使用するアプリケーション（ゲーム、画像生成AIなど）を終了する
2. GPU VRAM使用量を確認:

```powershell
nvidia-smi
```

3. RTX 4070 Ti SUPER (16GB) であればStyle-Bert-VITS2単体で問題になることは稀。他のモデルが同時にGPUメモリを占有していないか確認する
4. どうしても不足する場合は `config.yml` で `device: "cpu"` に変更（推論速度は大幅低下）

### 8-3. API接続エラー

**症状**: `speak_zundamon.ps1` がビープ音にフォールバックする

```powershell
# APIサーバーの生存確認
try {
    $info = Invoke-RestMethod -Uri "http://127.0.0.1:5000/models/info" -TimeoutSec 3
    Write-Host "APIサーバー: 稼働中" -ForegroundColor Green
    $info | ConvertTo-Json -Depth 3
} catch {
    Write-Host "APIサーバー: 停止中またはエラー" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
```

**対処法**:
1. サーバーが起動しているか確認（コンソールウィンドウが開いているか）
2. ポート5000が他のアプリに占有されていないか確認:

```powershell
Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue | Select-Object OwningProcess, State | ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{ PID = $_.OwningProcess; Name = $proc.ProcessName; State = $_.State }
}
```

3. ファイアウォールがローカルホスト通信をブロックしていないか確認（通常は問題にならない）

### 8-4. 音声が生成されない

**症状**: APIリクエストがエラーを返す、またはWAVファイルが空（0バイト）

**対処法**:
1. モデルが正しく配置されているか確認:

```powershell
Get-ChildItem -Path "C:\Users\zooyo\Style-Bert-VITS2\model_assets\zundamon" | Format-Table Name, Length
```

2. `config.json`、`*.safetensors`（または `*.pth`）、`style_vectors.npy` の3ファイルが揃っていること
3. `config.yml` の `limit` が十分か確認（300推奨）
4. テキストが空になっていないか確認（Markdown除去後に空になるケース）

### 8-5. speaker_name が見つからない

**症状**: APIが `speaker_name not found` エラーを返す

**対処法**:
1. 利用可能な話者一覧を取得:

```powershell
$models = Invoke-RestMethod -Uri "http://127.0.0.1:5000/models/info"
$models | ConvertTo-Json -Depth 5
```

2. レスポンスに含まれる話者名を確認し、`speak_zundamon.ps1` の `-SpeakerName` パラメータと一致させる
3. 配布元によって話者名が異なる場合がある（例: `zundamon`, `Zundamon`, `ずんだもん` など）
4. 話者名が異なる場合は、スクリプト呼び出し時にパラメータで上書き:

```powershell
# settings.json のHook設定で -SpeakerName を変更
# 例: -SpeakerName "Zundamon"
```

### 8-6. FFmpegエフェクトが適用されない

**症状**: 音声は再生されるがデジタルエフェクトがかからない（素のずんだもん音声）

**対処法**:
1. FFmpegがPATHに含まれているか確認:

```powershell
Get-Command ffmpeg -ErrorAction SilentlyContinue | Select-Object Source
```

2. 見つからない場合はPATHを再読み込み:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
Get-Command ffmpeg
```

3. `speak_zundamon.ps1` のデバッグログで詳細を確認:

```powershell
Get-Content (Join-Path $env:TEMP "zundamon_debug.log") -Tail 30
```

### 8-7. デバッグログの確認方法

`speak_zundamon.ps1` を `-Debug` スイッチ付きで実行した場合、ログが以下に出力される:

```powershell
# ずんだもんTTSデバッグログ
Get-Content (Join-Path $env:TEMP "zundamon_debug.log") -Tail 50

# FFmpegエラーログ
Get-Content (Join-Path $env:TEMP "ffmpeg_zundamon_err.txt")
```

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-01 | 初版作成 |
