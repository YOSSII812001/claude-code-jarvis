# register_voicevox_dict.ps1 - JSON word list to VOICEVOX user dictionary
param(
    [string]$VoicevoxUrl = "http://127.0.0.1:50021",
    [string]$JsonPath = (Join-Path $PSScriptRoot "voicevox_dict_words.json"),
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"

# VOICEVOX自動起動チェック
$voicevoxReady = $false
try {
    $null = Invoke-RestMethod -Uri "$VoicevoxUrl/version" -Method Get -TimeoutSec 2
    $voicevoxReady = $true
} catch {
    Write-Host "VOICEVOX not running, attempting auto-start..."
    $vvExe = "C:\Program Files\VOICEVOX\VOICEVOX.exe"
    if (-not (Test-Path $vvExe)) {
        $found = Get-ChildItem -Path "C:\Program Files","C:\Program Files (x86)",$env:LOCALAPPDATA -Recurse -Filter "VOICEVOX.exe" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $vvExe = $found.FullName }
    }
    if (Test-Path $vvExe) {
        Start-Process -FilePath $vvExe -WindowStyle Hidden
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            try {
                $null = Invoke-RestMethod -Uri "$VoicevoxUrl/version" -Method Get -TimeoutSec 2
                $voicevoxReady = $true
                Write-Host "VOICEVOX engine ready after $($i+1)s"
                break
            } catch { }
        }
    } else {
        Write-Host "VOICEVOX.exe not found"
    }
}
if (-not $voicevoxReady) {
    throw "VOICEVOX engine is not available at $VoicevoxUrl"
}

# Read JSON with explicit UTF-8
$json = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
$words = $json | ConvertFrom-Json

Write-Host "=== VOICEVOX Dict Registration ==="
Write-Host "Words: $($words.Count) | Mode: $(if($DryRun){'DRY RUN'}else{'LIVE'})"

# Fetch existing dict
$existingDict = @{}
try {
    $existing = Invoke-RestMethod -Uri "$VoicevoxUrl/user_dict" -Method Get -TimeoutSec 5
    foreach ($prop in $existing.PSObject.Properties) {
        $existingDict[$prop.Value.surface] = $prop.Name
    }
    Write-Host "Existing: $($existingDict.Count)"
} catch { Write-Host "Warning: $($_.Exception.Message)" }

$ok = 0; $skip = 0; $fail = 0

foreach ($w in $words) {
    if ($existingDict.ContainsKey($w.surface)) { $skip++; continue }
    if ($DryRun) { $ok++; continue }
    try {
        $uri = "$VoicevoxUrl/user_dict_word?surface=$([uri]::EscapeDataString($w.surface))&pronunciation=$([uri]::EscapeDataString($w.pronunciation))&accent_type=$($w.accent_type)"
        $null = Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 5
        $ok++
    } catch {
        Write-Host "  FAIL: $($w.surface) - $($_.Exception.Message)"
        $fail++
    }
}

Write-Host "=== Done: OK=$ok Skip=$skip Fail=$fail Total=$($words.Count) ==="
