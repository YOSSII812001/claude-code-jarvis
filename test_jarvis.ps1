# test_jarvis.ps1 - JARVIS Voice System Test
param(
    [switch]$ListSpeakers,
    [switch]$Tune,
    [int]$SpeakerId = 47,
    [string]$Text = "",
    [string]$VoicevoxUrl = "http://127.0.0.1:50021"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  JARVIS Voice System - Test Suite" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Connection Check ---
Write-Host "[1/4] VOICEVOX connection check..." -ForegroundColor Yellow

try {
    $version = Invoke-RestMethod -Uri ($VoicevoxUrl + "/version") -Method Get -TimeoutSec 5
    Write-Host "  OK - VOICEVOX v$version running" -ForegroundColor Green
} catch {
    Write-Host "  NG - Cannot connect to VOICEVOX" -ForegroundColor Red
    Write-Host "  1. Start VOICEVOX app" -ForegroundColor Gray
    Write-Host "  2. Engine should be at http://127.0.0.1:50021" -ForegroundColor Gray
    Write-Host "  Download: https://voicevox.hiroshiba.jp/" -ForegroundColor Cyan
    exit 1
}

# --- Step 2: List Speakers ---
Write-Host "[2/4] Fetching speakers..." -ForegroundColor Yellow

$speakers = Invoke-RestMethod -Uri ($VoicevoxUrl + "/speakers") -Method Get -TimeoutSec 10

if ($ListSpeakers) {
    Write-Host ""
    Write-Host "=== Available Speakers ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($speaker in $speakers) {
        Write-Host "  $($speaker.name)" -ForegroundColor White
        foreach ($style in $speaker.styles) {
            if ($style.id -eq $SpeakerId) {
                Write-Host "    ID: $($style.id) - $($style.name) [SELECTED]" -ForegroundColor Green
            } else {
                Write-Host "    ID: $($style.id) - $($style.name)" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
    Write-Host "JARVIS-recommended speakers:" -ForegroundColor Yellow
    Write-Host "  - Nurse Robot Type-T (Normal): Most mechanical/digital" -ForegroundColor Gray
    Write-Host "  - Shikoku Metan (Normal): Calm, low voice" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# Show current speaker
$currentSpeaker = "Unknown"
foreach ($speaker in $speakers) {
    foreach ($style in $speaker.styles) {
        if ($style.id -eq $SpeakerId) {
            $currentSpeaker = "$($speaker.name) ($($style.name))"
        }
    }
}
Write-Host ("  OK - {0} speakers found / Current: {1} (ID: {2})" -f $speakers.Count, $currentSpeaker, $SpeakerId) -ForegroundColor Green

# --- Step 3: Synthesis Test ---
Write-Host "[3/4] Synthesis test..." -ForegroundColor Yellow

if ($Text -eq "") {
    $Text = [System.Text.Encoding]::UTF8.GetString(
        [System.Convert]::FromBase64String("5LqG6Kej44GX44G+44GX44Gf44CB44K144O844CC44K344K544OG44Og44Gv5q2j5bi444Gr5YuV5L2c44GX44Gm44GE44G+44GZ44CC")
    )
}

$speedScale = 0.9
$pitchScale = -0.08
$intonationScale = 0.7
$volumeScale = 1.5

Write-Host "  Text: $Text" -ForegroundColor Gray
Write-Host ("  Params: speed={0} pitch={1} intonation={2} volume={3}" -f $speedScale, $pitchScale, $intonationScale, $volumeScale) -ForegroundColor Gray

# Audio Query
$encodedText = [uri]::EscapeDataString($Text)
$queryUri = "{0}/audio_query?text={1}&speaker={2}" -f $VoicevoxUrl, $encodedText, $SpeakerId
$query = Invoke-RestMethod -Uri $queryUri -Method Post -TimeoutSec 10

# Apply JARVIS parameters
$query.speedScale = $speedScale
$query.pitchScale = $pitchScale
$query.intonationScale = $intonationScale
$query.volumeScale = $volumeScale

# Synthesize
$queryJson = $query | ConvertTo-Json -Depth 10
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($queryJson)
$wavPath = Join-Path $env:TEMP "jarvis_test.wav"
$synthUri = "{0}/synthesis?speaker={1}" -f $VoicevoxUrl, $SpeakerId

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-WebRequest -Uri $synthUri -Method Post -Body $bodyBytes -ContentType "application/json" -OutFile $wavPath -TimeoutSec 30
$sw.Stop()

$fileSize = (Get-Item $wavPath).Length
$sizeKB = [math]::Round($fileSize / 1024, 1)
Write-Host ("  OK - Synthesis complete ({0}ms, {1}KB)" -f $sw.ElapsedMilliseconds, $sizeKB) -ForegroundColor Green

# --- Step 4: Playback Test ---
Write-Host "[4/4] Playback test..." -ForegroundColor Yellow
Write-Host "  Playing..." -ForegroundColor Gray

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WavPlayer {
    [DllImport("winmm.dll", SetLastError = true)]
    public static extern bool PlaySound(string pszSound, IntPtr hmod, uint fdwSound);
    public const uint SND_FILENAME = 0x00020000;
    public const uint SND_SYNC = 0x0000;
}
"@ -ErrorAction SilentlyContinue
[WavPlayer]::PlaySound($wavPath, [IntPtr]::Zero, [WavPlayer]::SND_FILENAME -bor [WavPlayer]::SND_SYNC)

Write-Host "  OK - Playback complete" -ForegroundColor Green

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "  All tests passed! JARVIS ready." -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""

# --- Tune Mode ---
if ($Tune) {
    Write-Host "=== Parameter Tuning Mode ===" -ForegroundColor Cyan
    Write-Host "Adjust parameters to find your ideal JARVIS voice." -ForegroundColor Gray
    Write-Host ""

    $tuneTextB64 = "5LqG6Kej44GX44G+44GX44Gf44CB44K144O844CC5Yem55CG44KS6ZaL5aeL44GX44G+44GZ44CC44K/44K544Kv44Gv5q2j5bi444Gr5a6M5LqG44GX44G+44GX44Gf44CC"
    $tuneText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tuneTextB64))

    while ($true) {
        Write-Host "--- Current Parameters ---" -ForegroundColor Yellow
        Write-Host ("  1. SpeedScale     : {0} (0.5-2.0, lower=slower)" -f $speedScale) -ForegroundColor White
        Write-Host ("  2. PitchScale     : {0} (-0.15-0.15, lower=deeper)" -f $pitchScale) -ForegroundColor White
        Write-Host ("  3. IntonationScale: {0} (0.0-2.0, lower=monotone)" -f $intonationScale) -ForegroundColor White
        Write-Host ("  4. VolumeScale    : {0} (0.0-2.0)" -f $volumeScale) -ForegroundColor White
        Write-Host ("  5. SpeakerId      : {0}" -f $SpeakerId) -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Parameter # to change (1-5, q=quit, p=play)"
        if ($choice -eq "q") { break }

        if ($choice -ne "p") {
            switch ($choice) {
                "1" { $val = Read-Host "SpeedScale ($speedScale)"; if ($val) { $speedScale = [double]$val } }
                "2" { $val = Read-Host "PitchScale ($pitchScale)"; if ($val) { $pitchScale = [double]$val } }
                "3" { $val = Read-Host "IntonationScale ($intonationScale)"; if ($val) { $intonationScale = [double]$val } }
                "4" { $val = Read-Host "VolumeScale ($volumeScale)"; if ($val) { $volumeScale = [double]$val } }
                "5" { $val = Read-Host "SpeakerId ($SpeakerId)"; if ($val) { $SpeakerId = [int]$val } }
            }
        }

        $encodedTune = [uri]::EscapeDataString($tuneText)
        $tuneQueryUri = "{0}/audio_query?text={1}&speaker={2}" -f $VoicevoxUrl, $encodedTune, $SpeakerId
        $tuneQuery = Invoke-RestMethod -Uri $tuneQueryUri -Method Post -TimeoutSec 10
        $tuneQuery.speedScale = $speedScale
        $tuneQuery.pitchScale = $pitchScale
        $tuneQuery.intonationScale = $intonationScale
        $tuneQuery.volumeScale = $volumeScale
        $tuneJson = $tuneQuery | ConvertTo-Json -Depth 10
        $tuneBytes = [System.Text.Encoding]::UTF8.GetBytes($tuneJson)
        $tuneSynthUri = "{0}/synthesis?speaker={1}" -f $VoicevoxUrl, $SpeakerId
        Invoke-WebRequest -Uri $tuneSynthUri -Method Post -Body $tuneBytes -ContentType "application/json" -OutFile $wavPath -TimeoutSec 30
        $player = New-Object System.Media.SoundPlayer($wavPath)
        $player.PlaySync()
    }

    Write-Host ""
    Write-Host "Final parameters:" -ForegroundColor Green
    Write-Host ("  -SpeakerId {0} -SpeedScale {1} -PitchScale {2} -IntonationScale {3} -VolumeScale {4}" -f $SpeakerId, $speedScale, $pitchScale, $intonationScale, $volumeScale) -ForegroundColor Cyan
}
