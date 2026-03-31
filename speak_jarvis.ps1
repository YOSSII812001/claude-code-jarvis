# speak_jarvis.ps1 - JARVIS風デジタル音声でClaudeの応答を読み上げ
#
# Claude Code Stop Hook から自動実行される
# VOICEVOXが起動していない場合はビープ音にフォールバック
#
# 単一プロセスで合成→バックグラウンド再生（Worker分離なし）
#
# パラメータ:
#   -SpeakerId       : VOICEVOX話者ID（デフォルト: 21 = 剣崎雌雄 ノーマル）
#   -SpeedScale      : 話速 0.5-2.0（デフォルト: 1.0）
#   -PitchScale      : 音高 -0.15-0.15（デフォルト: 0.06 = やや高め、聞き取りやすさ重視）
#   -IntonationScale : 抑揚 0.0-2.0（デフォルト: 0.8 = 自然な抑揚を保ちつつ落ち着き維持）
#   -VolumeScale     : 音量 0.0-2.0（デフォルト: 2.0）
#   -MaxLength       : 最大読み上げ文字数（デフォルト: 200）
#   -Debug           : デバッグログ出力

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
$wavPath = Join-Path $env:TEMP "jarvis_speech_$runId.wav"
$processedWav = Join-Path $env:TEMP "jarvis_digital_$runId.wav"
$debugLog = Join-Path $env:TEMP "jarvis_debug.log"

function Write-DebugLog {
    param([string]$Message)
    if ($Debug) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        "[$timestamp] $Message" | Out-File -FilePath $debugLog -Append -Encoding utf8
    }
}

function Invoke-BeepFallback {
    try {
        [Console]::Beep(800, 500)
        Start-Sleep -Milliseconds 150
        [Console]::Beep(1000, 500)
        Start-Sleep -Milliseconds 150
        [Console]::Beep(1200, 700)
    } catch {
        Write-Host "`a"
    }
}

function Remove-Markdown {
    param([string]$Text)

    # フェンスドコードブロック除去
    $Text = [regex]::Replace($Text, '```[\s\S]*?```', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    # インラインコード除去
    $Text = $Text -replace '`[^`]*`', ''
    # Markdownヘッダー除去
    $Text = $Text -replace '(?m)^#+\s+', ''
    # URL除去
    $Text = $Text -replace 'https?://\S+', ''
    # Markdownリンク [text](url) → text
    $Text = $Text -replace '\[([^\]]*)\]\([^\)]*\)', '$1'
    # 太字 **text** → text
    $Text = $Text -replace '\*\*([^*]*)\*\*', '$1'
    # 斜体 *text* → text
    $Text = $Text -replace '(?<!\*)\*([^*]+)\*(?!\*)', '$1'
    # リストマーカー除去
    $Text = $Text -replace '(?m)^[\s]*[-*]\s+', ''
    # 水平線除去
    $Text = $Text -replace '(?m)^---+\s*$', ''
    # テーブル区切り除去
    $Text = $Text -replace '(?m)^\|.*\|$', ''
    # 絵文字コード :emoji: 除去
    $Text = $Text -replace ':[a-zA-Z0-9_+-]+:', ''
    # 連続空白を1つのスペースに
    $Text = $Text -replace '\s+', ' '
    $Text = $Text.Trim()

    return $Text
}

function Truncate-Text {
    param([string]$Text, [int]$Max)

    if ($Text.Length -le $Max) { return $Text }

    # 文の区切りで切る（リテラル日本語文字はBOM無しで壊れるためchar code使用）
    $cutPoint = $Text.LastIndexOf([char]0x3002, $Max)  # 。
    if ($cutPoint -lt [math]::Floor($Max * 0.3)) {
        $cutPoint = $Text.LastIndexOf([char]0x3001, $Max)  # 、
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
# Main Flow: stdin → VOICEVOX合成 → FFmpegエフェクト → バックグラウンド再生
# ============================================================
Write-DebugLog "=== speak_jarvis started ==="

# Mutex（同時実行防止）
$mutex = [System.Threading.Mutex]::new($false, "Global\ClaudeJarvis")
$hasLock = $false

try {
    $hasLock = $mutex.WaitOne(0)
    if (-not $hasLock) {
        Write-DebugLog "Another instance running, exiting"
        exit 0
    }

    # クールダウンチェック
    $stateFile = Join-Path $env:TEMP "claude-jarvis-last-run.txt"
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

    # ── Phase 1: stdin読み取り + テキスト抽出 ──
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $inputText = [Console]::In.ReadToEnd()
    if (-not $inputText) {
        Write-DebugLog "No stdin received"
        exit 0
    }

    Write-DebugLog "Stdin received: $($inputText.Length) chars"

    # 他のフック（notify_toast.ps1等）がstdinを読めるよう一時ファイルに保存（BOMなしUTF-8）
    $sharedStdinPath = Join-Path $env:TEMP "claude_hook_stdin.json"
    try {
        [System.IO.File]::WriteAllText($sharedStdinPath, $inputText, (New-Object System.Text.UTF8Encoding $false))
    } catch {
        Write-DebugLog "Failed to save shared stdin: $_"
    }

    try {
        $data = $inputText | ConvertFrom-Json
    } catch {
        Write-DebugLog "Failed to parse JSON: $_"
        exit 0
    }

    $message = $data.last_assistant_message
    if (-not $message -or $message.Length -eq 0) {
        Write-DebugLog "No last_assistant_message found"
        if ($Debug) {
            $keys = $data.PSObject.Properties.Name -join ", "
            Write-DebugLog "Available JSON keys: $keys"
            $inputText | Out-File -FilePath (Join-Path $env:TEMP "jarvis_raw_stdin.json") -Encoding utf8
        }
        exit 0
    }

    # Markdown除去 → テキストクリーン → 文字数制限
    $cleanText = Remove-Markdown -Text $message
    if ($cleanText.Length -eq 0) {
        Write-DebugLog "Message empty after cleaning"
        exit 0
    }
    $cleanText = Truncate-Text -Text $cleanText -Max $MaxLength
    Write-DebugLog "Clean text ($($cleanText.Length) chars): $cleanText"

    # ── Phase 2: VOICEVOX接続チェック ──
    $voicevoxReady = $false
    try {
        $null = Invoke-RestMethod -Uri ($VoicevoxUrl + "/version") -Method Get -TimeoutSec 2
        $voicevoxReady = $true
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

    # ── Phase 3: VOICEVOX音声合成 ──
    $encodedText = [uri]::EscapeDataString($cleanText)
    Write-DebugLog "Creating audio query for speaker $SpeakerId"

    $audioQueryUri = "{0}/audio_query?text={1}&speaker={2}" -f $VoicevoxUrl, $encodedText, $SpeakerId
    $query = Invoke-RestMethod -Uri $audioQueryUri -Method Post -TimeoutSec 10

    # JARVIS風パラメータ適用
    $query.speedScale = $SpeedScale
    $query.pitchScale = $PitchScale
    $query.intonationScale = $IntonationScale
    $query.volumeScale = $VolumeScale

    # 母音短縮 + 終了余韻カット（自然な流れを保ちつつ語尾の伸びを防止）
    $query.prePhonemeLength = 0.12
    $query.postPhonemeLength = 0.15
    foreach ($phrase in $query.accent_phrases) {
        $moraCount = $phrase.moras.Count
        for ($i = 0; $i -lt $moraCount; $i++) {
            $m = $phrase.moras[$i]
            if ($i -eq $moraCount - 1) {
                # 最終モーラ: 80%に短縮、最低0.10秒は確保（語尾の自然さを維持）
                $m.vowel_length = [math]::Max($m.vowel_length * 0.80, 0.10)
            } elseif ($m.vowel_length -gt 0.20) {
                # 長い母音だけ93%に（短い母音はそのまま、閾値を上げて過剰短縮防止）
                $m.vowel_length = $m.vowel_length * 0.93
            }
        }
        if ($phrase.pause_mora -and $phrase.pause_mora.vowel_length) {
            # フレーズ間ポーズ: 88%に（間を詰めすぎない）
            $phrase.pause_mora.vowel_length = $phrase.pause_mora.vowel_length * 0.88
        }
    }

    # 疑問文の語尾上げ補正（is_interrogativeフラグがある最後のフレーズのピッチを上げる）
    $phraseCount = $query.accent_phrases.Count
    if ($phraseCount -gt 0) {
        $lastPhrase = $query.accent_phrases[$phraseCount - 1]
        if ($lastPhrase.is_interrogative -eq $true) {
            $mCount = $lastPhrase.moras.Count
            # 最後の2-3モーラのピッチを段階的に上げる（ごく控えめ）
            for ($i = [math]::Max(0, $mCount - 3); $i -lt $mCount; $i++) {
                $mora = $lastPhrase.moras[$i]
                if ($mora.pitch -gt 0) {
                    # 末尾に近いほど強く上げる（+0.1, +0.17, +0.25）
                    $boost = 0.1 + (($i - [math]::Max(0, $mCount - 3)) * 0.075)
                    $mora.pitch = $mora.pitch + $boost
                }
            }
            # 最終モーラの母音を少し伸ばす（語尾上げを聞き取りやすく）
            $lastMora = $lastPhrase.moras[$mCount - 1]
            $lastMora.vowel_length = [math]::Max($lastMora.vowel_length, 0.12)
            Write-DebugLog "Interrogative pitch boost applied to last phrase"
        }
    }

    Write-DebugLog "Parameters: speed=$SpeedScale pitch=$PitchScale intonation=$IntonationScale volume=$VolumeScale"

    # 音声合成
    $queryJson = $query | ConvertTo-Json -Depth 10
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($queryJson)

    Write-DebugLog "Synthesizing speech..."
    $synthUri = "{0}/synthesis?speaker={1}" -f $VoicevoxUrl, $SpeakerId
    Invoke-WebRequest -Uri $synthUri -Method Post -Body $bodyBytes -ContentType "application/json" -OutFile $wavPath -TimeoutSec 30

    # ── Phase 4: FFmpegデジタルエフェクト ──
    # フィルター構成:
    #   adelay        : 250ms初期ディレイ（登場感）
    #   highpass/low  : 帯域制限（通信機風）
    #   aecho         : 3タップ空間リバーブ（15/25/40ms で奥行きのある残響）
    #   aphaser       : 位相シフトで電子的な揺らぎ
    #   chorus        : 微細な二重化でシンセ的な厚み
    #   eq 1200Hz +2  : ミッド存在感
    #   eq 3200Hz +2.5: デジタルプレゼンス（高域の鋭さ、ノイズ抑制で控えめ）
    #   eq 5500Hz +0.8: エアー感（合成ノイズ増幅を抑制）
    #   volume        : 最終ゲイン
    $ffmpegFilter = "adelay=250|250,highpass=f=220,lowpass=f=4000,aecho=0.8:0.85:15|25|40:0.22|0.14|0.08,aphaser=in_gain=0.9:out_gain=0.9:delay=1.8:decay=0.10:speed=0.5:type=t,chorus=0.96:0.98:8|12:0.02|0.01:0.2|0.25:0.5|0.4,equalizer=f=1200:width_type=o:width=2:g=2,equalizer=f=3200:width_type=o:width=1.5:g=1.5,equalizer=f=5500:width_type=o:width=2:g=0,volume=1.6,apad=pad_dur=0.3"

    # PATH更新（wingetインストール後のffmpegを認識させる）
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

    $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($ffmpegCmd -and (Test-Path $wavPath)) {
        Write-DebugLog "Applying FFmpeg digital filter..."
        # -nostdin: stdin読み取り防止, -threads 1: 短いファイルのスレッド管理オーバーヘッド削減
        $ffmpegArgs = "-nostdin -y -threads 1 -i `"$wavPath`" -af `"$ffmpegFilter`" `"$processedWav`""
        Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -NoNewWindow -Wait -RedirectStandardError (Join-Path $env:TEMP "ffmpeg_err.txt")
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

        # ffplayが使えればそちらを優先（軽量・即起動）
        $ffplayCmd = Get-Command ffplay -ErrorAction SilentlyContinue
        if ($ffplayCmd) {
            Start-Process -WindowStyle Hidden -FilePath "ffplay" -ArgumentList "-nodisp", "-autoexit", "-loglevel", "quiet", "`"$playFile`""
            Write-DebugLog "Playback via ffplay (background)"
        } else {
            # フォールバック: 再生用スクリプトをTEMPに書き出して実行
            $playScript = Join-Path $env:TEMP "jarvis_play.ps1"
            $escapedPath = $playFile -replace "'", "''"
            @"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WP {
    [DllImport("winmm.dll")]
    public static extern bool PlaySound(string s, IntPtr h, uint f);
}
'@
[WP]::PlaySound('$escapedPath', [IntPtr]::Zero, 0x20000)
"@ | Set-Content -Path $playScript -Encoding utf8
            Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $playScript
            Write-DebugLog "Playback via PlaySound fallback (background)"
        }
    }

    # 古いJARVIS一時ファイルをクリーンアップ（60秒以上経過したものだけ削除 — 再生中のファイルを守る）
    $cleanupThreshold = (Get-Date).AddSeconds(-60)
    Get-ChildItem -Path $env:TEMP -Filter "jarvis_speech_*.wav" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cleanupThreshold } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter "jarvis_digital_*.wav" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cleanupThreshold } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter "jarvis_play_*.ps1" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cleanupThreshold } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    # 旧固定ファイル名も削除
    Remove-Item -Path (Join-Path $env:TEMP "jarvis_speech.wav") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "jarvis_digital.wav") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "jarvis_pending.txt") -Force -ErrorAction SilentlyContinue

    Write-DebugLog "=== speak_jarvis complete ==="

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
