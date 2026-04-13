# cleanup_dict_duplicates.ps1 - Remove duplicate entries from VOICEVOX user dictionary
param([string]$VoicevoxUrl = "http://127.0.0.1:50021")

$url = $VoicevoxUrl
$dict = Invoke-RestMethod -Uri "$url/user_dict" -Method Get

# surface -> list of IDs
$surfaceMap = @{}
foreach ($prop in $dict.PSObject.Properties) {
    $s = $prop.Value.surface
    if (-not $surfaceMap.ContainsKey($s)) {
        $surfaceMap[$s] = [System.Collections.ArrayList]::new()
    }
    [void]$surfaceMap[$s].Add($prop.Name)
}

# Find duplicates: keep first, delete rest
$deleteIds = @()
$dupReport = @()
foreach ($kv in $surfaceMap.GetEnumerator()) {
    if ($kv.Value.Count -gt 1) {
        $surface = $kv.Key
        $ids = $kv.Value
        $pron = $dict.($ids[0]).pronunciation
        $dupReport += "$surface ($pron) x$($ids.Count)"
        for ($i = 1; $i -lt $ids.Count; $i++) {
            $deleteIds += $ids[$i]
        }
    }
}

Write-Host "=== Duplicate Report ==="
Write-Host "Total entries: $(@($dict.PSObject.Properties).Count)"
Write-Host "Duplicates found: $($dupReport.Count) words ($($deleteIds.Count) entries to remove)"
foreach ($d in $dupReport) { Write-Host "  $d" }

# Delete duplicates
$deleted = 0
foreach ($id in $deleteIds) {
    try {
        Invoke-RestMethod -Uri "$url/user_dict_word/$id" -Method Delete -TimeoutSec 5
        $deleted++
    } catch {
        Write-Host "  FAIL: $id - $($_.Exception.Message)"
    }
}

$finalCount = @((Invoke-RestMethod -Uri "$url/user_dict" -Method Get).PSObject.Properties).Count
Write-Host "=== Done: Removed $deleted, Final count: $finalCount ==="
