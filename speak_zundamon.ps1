# speak_zundamon.ps1 - JARVIS風音声でClaudeの応答を読み上げ（VOICEVOX版）
#
# Claude Code Stop Hook から自動実行される
# フラグファイル（%TEMP%\zundamon_tts_active.txt）が存在する場合のみ動作
# VOICEVOXが起動していない場合はビープ音にフォールバック
#
# パラメータ:
#   -SpeakerId        : VOICEVOX話者ID（デフォルト: 84 = 青山龍星 しっとり）
#   -SpeedScale       : 話速 0.5-2.0（デフォルト: 1.0）
#   -PitchScale       : 音高 -0.15-0.15（デフォルト: 0.0）
#   -IntonationScale  : 抑揚 0.0-2.0（デフォルト: 0.5 = 抑え目）
#   -VolumeScale      : 音量 0.0-2.0（デフォルト: 1.4）
#   -MaxLength        : 最大読み上げ文字数（デフォルト: 250）
#   -Debug            : デバッグログ出力

param(
    [switch]$Debug,
    [int]$SpeakerId = 21,
    [double]$SpeedScale = 1.0,
    [double]$PitchScale = 0.06,
    [double]$IntonationScale = 0.8,
    [double]$VolumeScale = 1.4,
    [int]$MaxLength = 250,
    [string]$VoicevoxUrl = "http://127.0.0.1:50021",
    [int]$CooldownSeconds = 5
)

$ErrorActionPreference = "SilentlyContinue"
$runId = [guid]::NewGuid().ToString("N").Substring(0, 8)
$wavPath = Join-Path $env:TEMP "zundamon_speech_$runId.wav"
$processedWav = Join-Path $env:TEMP "zundamon_digital_$runId.wav"
$debugLog = Join-Path $env:TEMP "zundamon_debug.log"

function Write-DebugLog {
    param([string]$Message)
    if ($Debug) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        "[$timestamp] $Message" | Out-File -FilePath $debugLog -Append -Encoding utf8
    }
}

# ── Phase 0: フラグチェック ──
$zundamonFlag = Join-Path $env:TEMP "zundamon_tts_active.txt"
if (-not (Test-Path $zundamonFlag)) {
    exit 0
}

Write-DebugLog "=== speak_zundamon started ==="

function Invoke-BeepFallback {
    try {
        [Console]::Beep(600, 300)
        Start-Sleep -Milliseconds 100
        [Console]::Beep(800, 300)
        Start-Sleep -Milliseconds 100
        [Console]::Beep(600, 400)
    } catch {
        Write-Host "`a"
    }
}

function Remove-Markdown {
    param([string]$Text)
    $Text = [regex]::Replace($Text, '```[\s\S]*?```', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $Text = $Text -replace '`[^`]*`', ''
    $Text = $Text -replace '(?m)^#+\s+', ''
    $Text = $Text -replace 'https?://\S+', ''
    $Text = $Text -replace '\[([^\]]*)\]\([^\)]*\)', '$1'
    $Text = $Text -replace '\*\*([^*]*)\*\*', '$1'
    $Text = $Text -replace '(?<!\*)\*([^*]+)\*(?!\*)', '$1'
    $Text = $Text -replace '(?m)^[\s]*[-*]\s+', ''
    $Text = $Text -replace '(?m)^---+\s*$', ''
    $Text = $Text -replace '(?m)^\|.*\|$', ''
    $Text = $Text -replace ':[a-zA-Z0-9_+-]+:', ''
    $Text = $Text -replace '\s+', ' '
    $Text = $Text.Trim()
    return $Text
}

function Truncate-Text {
    param([string]$Text, [int]$Max)
    if ($Text.Length -le $Max) { return $Text }
    $cutPoint = $Text.LastIndexOf([char]0x3002, $Max)
    if ($cutPoint -lt [math]::Floor($Max * 0.3)) {
        $cutPoint = $Text.LastIndexOf([char]0x3001, $Max)
    }
    if ($cutPoint -lt [math]::Floor($Max * 0.3)) {
        $cutPoint = $Text.LastIndexOf('. ', $Max)
    }
    if ($cutPoint -lt [math]::Floor($Max * 0.3)) {
        $cutPoint = $Max
    }
    return $Text.Substring(0, $cutPoint + 1)
}

# ============================================================
# Main Flow: stdin -> VOICEVOX合成 -> FFmpegエフェクト -> バックグラウンド再生
# ============================================================

# Mutex（同時実行防止）
$mutex = [System.Threading.Mutex]::new($false, "Global\ClaudeZundamon")
$hasLock = $false

try {
    $hasLock = $mutex.WaitOne(0)
    if (-not $hasLock) {
        Write-DebugLog "Another instance running, exiting"
        exit 0
    }

    # クールダウンチェック
    $stateFile = Join-Path $env:TEMP "claude-zundamon-last-run.txt"
    $now = Get-Date
    if (Test-Path $stateFile) {
        $lastRaw = Get-Content -Path $stateFile -Raw -ErrorAction SilentlyContinue
        $lastRun = [datetime]::MinValue
        if ([datetime]::TryParse($lastRaw, [ref]$lastRun)) {
            $elapsed = ($now - $lastRun).TotalSeconds
            if ($elapsed -lt $CooldownSeconds) {
                Write-DebugLog "Cooldown active ($elapsed < $CooldownSeconds sec)"
                exit 0
            }
        }
    }
    $now.ToString("o") | Set-Content -Path $stateFile -Encoding ascii

    # ── Phase 1: 共有stdinファイルから読み取り（JARVISが先に保存済み） ──
    Write-DebugLog "Phase 1: Reading shared stdin file..."
    $sharedStdinPath = Join-Path $env:TEMP "claude_hook_stdin.json"
    $inputText = $null
    if (Test-Path $sharedStdinPath) {
        $inputText = [System.IO.File]::ReadAllText($sharedStdinPath, [System.Text.Encoding]::UTF8)
    }
    if (-not $inputText) {
        Write-DebugLog "No shared stdin file found"
        exit 0
    }
    Write-DebugLog "Stdin received: $($inputText.Length) chars"

    try {
        $data = $inputText | ConvertFrom-Json
    } catch {
        Write-DebugLog "Failed to parse JSON: $_"
        exit 0
    }

    $message = $data.last_assistant_message
    if (-not $message -or $message.Length -eq 0) {
        Write-DebugLog "No last_assistant_message found"
        exit 0
    }

    $cleanText = Remove-Markdown -Text $message
    if ($cleanText.Length -eq 0) {
        Write-DebugLog "Message empty after cleaning"
        exit 0
    }
    $cleanText = Truncate-Text -Text $cleanText -Max $MaxLength
    Write-DebugLog "Clean text ($($cleanText.Length) chars): $cleanText"

    # ── Phase 2: VOICEVOX接続チェック（未起動時は自動起動） ──
    $voicevoxReady = $false
    try {
        $null = Invoke-RestMethod -Uri ($VoicevoxUrl + "/version") -Method Get -TimeoutSec 2
        $voicevoxReady = $true
        Write-DebugLog "VOICEVOX is running"
    } catch {
        Write-DebugLog "VOICEVOX not running, attempting auto-start..."
        $vvExe = "C:\Program Files\VOICEVOX\VOICEVOX.exe"
        if (-not (Test-Path $vvExe)) {
            $found = Get-ChildItem -Path "C:\Program Files","C:\Program Files (x86)",$env:LOCALAPPDATA -Recurse -Filter "VOICEVOX.exe" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $vvExe = $found.FullName }
        }
        if (Test-Path $vvExe) {
            Start-Process -FilePath $vvExe -WindowStyle Hidden
            Write-DebugLog "Started VOICEVOX, waiting for engine..."
            for ($i = 0; $i -lt 15; $i++) {
                Start-Sleep -Seconds 1
                try {
                    $null = Invoke-RestMethod -Uri ($VoicevoxUrl + "/version") -Method Get -TimeoutSec 2
                    $voicevoxReady = $true
                    Write-DebugLog "VOICEVOX engine ready after $($i+1)s"
                    break
                } catch { }
            }
        } else {
            Write-DebugLog "VOICEVOX.exe not found"
        }
    }
    if (-not $voicevoxReady) {
        Write-DebugLog "VOICEVOX unavailable, falling back to beep"
        Invoke-BeepFallback
        exit 0
    }

    # ── Phase 3: VOICEVOX音声合成（audio_query + パラメータ調整 + synthesis） ──
    $encodedText = [uri]::EscapeDataString($cleanText)
    Write-DebugLog "Creating audio query for speaker $SpeakerId"

    $audioQueryUri = "{0}/audio_query?text={1}&speaker={2}" -f $VoicevoxUrl, $encodedText, $SpeakerId
    $query = Invoke-RestMethod -Uri $audioQueryUri -Method Post -TimeoutSec 10

    # パラメータ適用
    $query.speedScale = $SpeedScale
    $query.pitchScale = $PitchScale
    $query.intonationScale = $IntonationScale
    $query.volumeScale = $VolumeScale
    $query.prePhonemeLength = 0.1
    $query.postPhonemeLength = 0.1

    # 母音短縮（JARVISと同じ方式）
    foreach ($phrase in $query.accent_phrases) {
        $moraCount = $phrase.moras.Count
        for ($i = 0; $i -lt $moraCount; $i++) {
            $m = $phrase.moras[$i]
            if ($i -eq $moraCount - 1) {
                $m.vowel_length = [math]::Max($m.vowel_length * 0.80, 0.10)
            } elseif ($m.vowel_length -gt 0.20) {
                $m.vowel_length = $m.vowel_length * 0.93
            }
        }
        if ($phrase.pause_mora -and $phrase.pause_mora.vowel_length) {
            $phrase.pause_mora.vowel_length = $phrase.pause_mora.vowel_length * 0.88
        }
    }

    Write-DebugLog "Parameters: speed=$SpeedScale pitch=$PitchScale intonation=$IntonationScale volume=$VolumeScale"

    # 音声合成
    $queryJson = $query | ConvertTo-Json -Depth 10
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($queryJson)
    $synthUri = "{0}/synthesis?speaker={1}" -f $VoicevoxUrl, $SpeakerId
    Write-DebugLog "Synthesizing speech..."
    Invoke-WebRequest -Uri $synthUri -Method Post -Body $bodyBytes -ContentType "application/json" -OutFile $wavPath -TimeoutSec 30

    if (-not (Test-Path $wavPath) -or (Get-Item $wavPath).Length -lt 100) {
        Write-DebugLog "WAV file missing or too small"
        Invoke-BeepFallback
        exit 0
    }
    Write-DebugLog "WAV generated: $((Get-Item $wavPath).Length) bytes"

    # ── Phase 4: FFmpegデジタルエフェクト（JARVIS風） ──
    $ffmpegFilter = "adelay=250|250,highpass=f=220,lowpass=f=4000,aecho=0.8:0.85:15|25|40:0.22|0.14|0.08,aphaser=in_gain=0.9:out_gain=0.9:delay=1.8:decay=0.10:speed=0.5:type=t,chorus=0.96:0.98:8|12:0.02|0.01:0.2|0.25:0.5|0.4,equalizer=f=1200:width_type=o:width=2:g=2,equalizer=f=3200:width_type=o:width=1.5:g=1.5,equalizer=f=5500:width_type=o:width=2:g=0,volume=1.6,apad=pad_dur=0.3"

    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
    $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($ffmpegCmd -and (Test-Path $wavPath)) {
        Write-DebugLog "Applying FFmpeg digital filter..."
        $ffmpegArgs = "-nostdin -y -threads 1 -i `"$wavPath`" -af `"$ffmpegFilter`" `"$processedWav`""
        Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -NoNewWindow -Wait -RedirectStandardError (Join-Path $env:TEMP "ffmpeg_zundamon_err.txt")
        if (Test-Path $processedWav) {
            $playFile = $processedWav
            Write-DebugLog "Digital filter applied"
        } else {
            $playFile = $wavPath
            Write-DebugLog "FFmpeg failed, using raw"
        }
    } else {
        $playFile = $wavPath
        Write-DebugLog "FFmpeg not found, using raw"
    }

    # ── Phase 5: バックグラウンド再生 ──
    if (Test-Path $playFile) {
        Write-DebugLog "Starting background playback: $playFile"
        $ffplayCmd = Get-Command ffplay -ErrorAction SilentlyContinue
        if ($ffplayCmd) {
            Start-Process -WindowStyle Hidden -FilePath "ffplay" -ArgumentList "-nodisp", "-autoexit", "-loglevel", "quiet", "`"$playFile`""
            Write-DebugLog "Playback via ffplay (background)"
        } else {
            $playScript = Join-Path $env:TEMP "zundamon_play.ps1"
            $escapedPath = $playFile -replace "'", "''"
            @"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ZP {
    [DllImport("winmm.dll")]
    public static extern bool PlaySound(string s, IntPtr h, uint f);
}
'@
[ZP]::PlaySound('$escapedPath', [IntPtr]::Zero, 0x20000)
"@ | Set-Content -Path $playScript -Encoding utf8
            Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $playScript
            Write-DebugLog "Playback via PlaySound fallback (background)"
        }
    }

    # クリーンアップ
    $cleanupThreshold = (Get-Date).AddSeconds(-60)
    Get-ChildItem -Path $env:TEMP -Filter "zundamon_speech_*.wav" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cleanupThreshold } | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter "zundamon_digital_*.wav" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cleanupThreshold } | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-DebugLog "=== speak_zundamon complete ==="

} catch {
    Write-DebugLog "Error: $_"
    Invoke-BeepFallback
} finally {
    if ($hasLock) {
        $mutex.ReleaseMutex() | Out-Null
    }
    $mutex.Dispose()
}

exit 0
