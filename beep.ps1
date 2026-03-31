param(
    [double]$Volume = 0.08,
    [int]$Frequency = 800,
    [int]$Duration = 500,
    [int]$CooldownSeconds = 8
)

$mutexName = "Global\ClaudeBeepLock"
$stateFile = Join-Path $env:TEMP "claude-beep-last-run.txt"
$mutex = [System.Threading.Mutex]::new($false, $mutexName)
$hasLock = $false

try {
    # Skip if another hook invocation is currently playing the chime.
    $hasLock = $mutex.WaitOne(0)
    if (-not $hasLock) {
        exit 0
    }

    $now = Get-Date
    if (Test-Path $stateFile) {
        $lastRaw = Get-Content -Path $stateFile -Raw -ErrorAction SilentlyContinue
        $lastRun = [datetime]::MinValue
        if ([datetime]::TryParse($lastRaw, [ref]$lastRun)) {
            $elapsed = ($now - $lastRun).TotalSeconds
            if ($elapsed -lt $CooldownSeconds) {
                exit 0
            }
        }
    }

    $now.ToString("o") | Set-Content -Path $stateFile -Encoding ascii

    # Windows beep using .NET Console.Beep (no external dependencies)
    # 3-tone chime: low -> mid -> high, each 500ms for clear audibility
    try {
        [Console]::Beep($Frequency, $Duration)
        Start-Sleep -Milliseconds 150
        [Console]::Beep($Frequency + 200, $Duration)
        Start-Sleep -Milliseconds 150
        [Console]::Beep($Frequency + 400, $Duration + 200)
    } catch {
        # Fallback: use PowerShell media player for beep
        try {
            Add-Type -AssemblyName System.Media
            $player = New-Object System.Media.SoundPlayer
            $player.SoundLocation = "$env:SystemRoot\Media\Windows Notify Calendar.wav"
            if (Test-Path $player.SoundLocation) {
                $player.PlaySync()
            } else {
                # Last resort: simple BEL character
                Write-Host "`a"
            }
        } catch {
            Write-Host "`a"
        }
    }
} finally {
    if ($hasLock) {
        $mutex.ReleaseMutex() | Out-Null
    }
    $mutex.Dispose()
}
