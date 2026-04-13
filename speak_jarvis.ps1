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
#   -MaxLength       : 最大読み上げ文字数（デフォルト: 375）
#   -Debug           : デバッグログ出力

param(
    [switch]$Debug,
    [int]$SpeakerId = 21,
    [double]$SpeedScale = 1.0,
    [double]$PitchScale = 0.06,
    [double]$IntonationScale = 0.8,
    [double]$VolumeScale = 1.4,
    [int]$MaxLength = 375,
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

function New-StartupSound {
    param([string]$OutputPath)

    $sampleRate = 24000
    $duration = 0.8
    $samples = [int]($sampleRate * $duration)
    $bitsPerSample = 16
    $channels = 1
    $dataSize = $samples * $channels * ($bitsPerSample / 8)

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # WAV header
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int]($dataSize + 36))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int]16)
    $bw.Write([int16]1)       # PCM
    $bw.Write([int16]$channels)
    $bw.Write([int]$sampleRate)
    $bw.Write([int]($sampleRate * $channels * $bitsPerSample / 8))
    $bw.Write([int16]($channels * $bitsPerSample / 8))
    $bw.Write([int16]$bitsPerSample)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int]$dataSize)

    # JARVIS起動音（バイザー風）: 重低音チャージ + 金属レゾナンス融合
    # 位相アキュムレータ（周波数ステップ境界での位相不連続＝音切れを防止）
    $ph = 0.0

    for ($i = 0; $i -lt $samples; $i++) {
        $t = $i / $sampleRate
        $progress = $i / $samples

        # 周波数スイープ: 20Hzステップで量子化（ギア的な段差感）
        $freqSmooth = 80 * [math]::Pow(300 / 80, $progress)
        $freq = [math]::Floor($freqSmooth / 20) * 20

        # 位相を滑らかに蓄積（freqが変わっても位相は連続）
        $ph += $freq / $sampleRate

        # 深いFM変調（整数比×2 = 金属的なバズ音）
        $modulator = [math]::Sin(2 * [math]::PI * $ph * 2.0) * 0.7
        $sample = [math]::Sin(2 * [math]::PI * $ph + $modulator) * 0.3

        # リング変調: キャリア×低周波 = 非調和な機械ノイズ
        $ring = [math]::Sin(2 * [math]::PI * $ph) * [math]::Sin(2 * [math]::PI * 37 * $t)
        $sample += $ring * 0.2

        # パルス波（矩形波）: 硬質なバズ感
        $pulse = [math]::Sign([math]::Sin(2 * [math]::PI * $ph * 0.5))
        $sample += $pulse * 0.08

        # サーボモーター: 高周波×低周波の振幅変調でウィーン音
        $servo = [math]::Sin(2 * [math]::PI * $ph * 4) * [math]::Sin(2 * [math]::PI * 7 * $t)
        $sample += $servo * 0.07 * $progress

        # デチューン + サブオクターブ
        $sample += [math]::Sin(2 * [math]::PI * $ph * 1.004) * 0.2
        $sample += [math]::Sin(2 * [math]::PI * $ph * 0.5) * 0.25

        # 非整数倍音（金属レゾナンス、progressでフェードイン）
        $metalMix = [math]::Pow($progress, 2)
        $sample += [math]::Sin(2 * [math]::PI * $ph * 2.76) * 0.15 * $metalMix
        $sample += [math]::Sin(2 * [math]::PI * $ph * 5.4) * 0.1 * $metalMix

        # エンベロープ: アタック → サスティーン → コサインリリース（滑らかな減衰）
        if ($progress -lt 0.015) {
            $env = ($progress / 0.015) * 1.8                               # アタック（180%オーバーシュート）
        } elseif ($progress -lt 0.08) {
            $env = 1.8 - 0.8 * (($progress - 0.015) / 0.065)             # ピークから1.0へ戻る
        } elseif ($progress -lt 0.4) {
            $env = 0.7 + 0.3 * (($progress - 0.08) / 0.32)               # サスティーン（微増）
        } else {
            $rel = ($progress - 0.4) / 0.6                                # ロングフェードアウト（60%）
            $env = (1.0 + [math]::Cos([math]::PI * $rel)) / 2.0          # コサインカーブ
        }
        $sample *= $env * 0.85

        $value = [int]($sample * 32767)
        $value = [math]::Max(-32768, [math]::Min(32767, $value))
        $bw.Write([int16]$value)
    }

    [System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())
    $bw.Close()
    $ms.Close()
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

# stdin読み取りを先に行い、共有ファイルに保存（ずんだもん用）
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$rawStdin = [Console]::In.ReadToEnd()
$sharedStdinPath = Join-Path $env:TEMP "claude_hook_stdin.json"
if ($rawStdin) {
    try {
        [System.IO.File]::WriteAllText($sharedStdinPath, $rawStdin, (New-Object System.Text.UTF8Encoding $false))
        Write-DebugLog "Shared stdin saved: $($rawStdin.Length) chars"
    } catch {
        Write-DebugLog "Failed to save shared stdin: $_"
    }
}

# ずんだもんTTSが有効な場合はJARVISをスキップ
$zundamonFlag = Join-Path $env:TEMP "zundamon_tts_active.txt"
if (Test-Path $zundamonFlag) {
    Write-DebugLog "Zundamon TTS active, skipping JARVIS"
    exit 0
}

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

    # ── Phase 1: stdin（冒頭で読み取り・保存済みの$rawStdinを使用） ──
    $inputText = $rawStdin
    if (-not $inputText) {
        Write-DebugLog "No stdin received"
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

    # ── Phase 4+5: ffplayで直接フィルター適用＋再生（FFmpegプロセス不要） ──
    # フィルター構成:
    #   highpass/low  : 帯域制限（通信機風）
    #   aecho         : 4タップ空間リバーブ（15/30/50/75ms で奥行きのある残響）
    #   chorus        : 微細な二重化でシンセ的な厚み
    #   eq 1200Hz +2  : ミッド存在感
    #   eq 3200Hz +1.5: デジタルプレゼンス
    #   volume        : 最終ゲイン
    # ※ adelay削除（即再生）、aphaser削除（処理負荷大・効果小）
    $jarvisFilter = 'highpass=f=220,lowpass=f=4000,aecho=0.8:0.88:15|30|50|75:0.35|0.25|0.15|0.08,chorus=0.93:0.96:8|14:0.03|0.02:0.25|0.3:0.5|0.4,equalizer=f=1200:width_type=o:width=2:g=2,equalizer=f=3200:width_type=o:width=1.5:g=1.5,volume=1.6'

    # 起動音専用フィルター: 低域を活かす（highpass 60Hz）+ 重めのエコー + 低域ブースト + 余韻パディング
    $startupFilter = 'highpass=f=60,lowpass=f=3000,aecho=0.8:0.85:25|50|80|120:0.45|0.35|0.25|0.12,chorus=0.9:0.95:12|20:0.04|0.03:0.3|0.35:0.5|0.4,equalizer=f=200:width_type=o:width=2:g=4,equalizer=f=450:width_type=o:width=2:g=2,volume=2.0,apad=pad_dur=0.5'

    # PATH更新（wingetインストール後のffplay/ffmpegを認識させる）
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

    # ── 再生重複防止: JARVIS再生プロセスが進行中ならスキップ ──
    $existingPlayer = Get-CimInstance Win32_Process -Filter "Name='ffplay.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -eq 'ffplay.exe' -and $_.CommandLine -like "*jarvis_speech_*") -or
            ($_.Name -eq 'powershell.exe' -and $_.CommandLine -like "*jarvis_play*")
        }
    if ($existingPlayer) {
        Write-DebugLog "JARVIS playback already active (PID: $($existingPlayer.ProcessId)), skipping"
        Remove-Item -Path @($wavPath, $processedWav) -Force -ErrorAction SilentlyContinue
        exit 0
    }

    if (Test-Path $wavPath) {
        Write-DebugLog "Starting playback with digital filter: $wavPath"

        # ── 起動音の生成（キャッシュ）＋再生 ──
        $startupWav = Join-Path $env:TEMP "jarvis_startup.wav"
        if (-not (Test-Path $startupWav)) {
            Write-DebugLog "Generating startup sound..."
            New-StartupSound -OutputPath $startupWav
        }

        $ffplayCmd = Get-Command ffplay -ErrorAction SilentlyContinue
        if ($ffplayCmd) {
            # 起動音を再生（非ブロッキング — 音声と並行再生）
            if (Test-Path $startupWav) {
                Start-Process -WindowStyle Hidden -FilePath "ffplay" -ArgumentList "-nodisp", "-autoexit", "-loglevel", "quiet", "-af", $startupFilter, "`"$startupWav`""
                Write-DebugLog "Startup sound started (non-blocking)"
                Start-Sleep -Milliseconds 300  # 起動音の頭だけ聞かせてから音声開始
            }
            # 音声読み上げ（バックグラウンド — 非ブロッキング）
            Start-Process -WindowStyle Hidden -FilePath "ffplay" -ArgumentList "-nodisp", "-autoexit", "-loglevel", "quiet", "-af", $jarvisFilter, "`"$wavPath`""
            Write-DebugLog "Playback via ffplay with direct filter (background)"
        } else {
            # フォールバック: FFmpegでフィルター適用後にPlaySoundで再生
            $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
            if ($ffmpegCmd) {
                Write-DebugLog "ffplay not found, falling back to FFmpeg + PlaySound"
                $ffmpegArgs = "-nostdin -y -threads 1 -i `"$wavPath`" -af `"$jarvisFilter`" `"$processedWav`""
                Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -NoNewWindow -Wait -RedirectStandardError (Join-Path $env:TEMP "ffmpeg_err.txt")
                if (Test-Path $processedWav) { $wavPath = $processedWav }
            }
            $playScript = Join-Path $env:TEMP "jarvis_play.ps1"
            $escapedPath = $wavPath -replace "'", "''"
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
