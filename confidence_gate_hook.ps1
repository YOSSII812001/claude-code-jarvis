param(
    [switch]$Debug,
    [switch]$Test,
    [int]$CooldownSeconds = 120,
    [int]$ScoreThreshold = 5
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$debugLog = Join-Path $env:TEMP "confidence_gate_debug.log"
$cooldownFile = Join-Path $env:TEMP "claude-confidence-gate-last.txt"

function Write-DebugLog {
    param([string]$Message)
    if ($Debug -or $Test) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        "[$timestamp] [gate] $Message" | Out-File -FilePath $debugLog -Append -Encoding utf8
    }
}

# Japanese string constants via char codes (BOM-independent)
$JP_TEST_RESULT   = "" + [char]0x30C6 + [char]0x30B9 + [char]0x30C8 + [char]0x7D50 + [char]0x679C
$JP_TEST_COMPLETE = "" + [char]0x30C6 + [char]0x30B9 + [char]0x30C8 + [char]0x5B8C + [char]0x4E86
$JP_TEST_REPORT   = "" + [char]0x30C6 + [char]0x30B9 + [char]0x30C8 + [char]0x5831 + [char]0x544A
$JP_E2E_RESULT    = "E2E" + [char]0x7D50 + [char]0x679C
$JP_TEST_PLAN     = "" + [char]0x30C6 + [char]0x30B9 + [char]0x30C8 + [char]0x8A08 + [char]0x753B
$JP_PHASE         = "" + [char]0x30D5 + [char]0x30A7 + [char]0x30FC + [char]0x30BA
$JP_TEST          = "" + [char]0x30C6 + [char]0x30B9 + [char]0x30C8

# Gate output text (char code construction for BOM-independent Japanese output)
$GATE_LINE1 = "[CONFIDENCE GATE] E2E" + $JP_TEST_RESULT + `
    [char]0x5831 + [char]0x544A + [char]0x3092 + [char]0x691C + [char]0x51FA + `
    [char]0x3057 + [char]0x307E + [char]0x3057 + [char]0x305F + [char]0x3002
# [CONFIDENCE GATE] E2Eテスト結果報告を検出しました。

$GATE_LINE2 = [char]0x5831 + [char]0x544A + [char]0x3092 + [char]0x78BA + [char]0x5B9A + `
    [char]0x3059 + [char]0x308B + [char]0x524D + [char]0x306B + [char]0x3001 + `
    [char]0x4EE5 + [char]0x4E0B + "6" + [char]0x554F + [char]0x306B + `
    [char]0x8A3C + [char]0x8DE1 + [char]0x4ED8 + [char]0x304D + [char]0x3067 + `
    [char]0x56DE + [char]0x7B54 + [char]0x3057 + [char]0x3066 + [char]0x304F + `
    [char]0x3060 + [char]0x3055 + [char]0x3044 + [char]0x3002
# 報告を確定する前に、以下6問に証跡付きで回答してください。

$GATE_LINE3 = "1" + [char]0x3064 + [char]0x3067 + [char]0x3082 + `
    [char]0x300C + [char]0x3044 + [char]0x3044 + [char]0x3048 + [char]0x300D + `
    [char]0x306A + [char]0x3089 + [char]0x8FFD + [char]0x52A0 + $JP_TEST + `
    [char]0x3092 + [char]0x5B9F + [char]0x884C + [char]0x3057 + [char]0x3066 + `
    [char]0x304B + [char]0x3089 + [char]0x518D + [char]0x5831 + [char]0x544A + `
    [char]0x3057 + [char]0x3066 + [char]0x304F + [char]0x3060 + [char]0x3055 + `
    [char]0x3044 + [char]0x3002
# 1つでも「いいえ」なら追加テストを実行してから再報告してください。

# C1: 修正対象の機能を直接操作したか？
$GATE_C1 = "C1: " + [char]0x4FEE + [char]0x6B63 + [char]0x5BFE + [char]0x8C61 + `
    [char]0x306E + [char]0x6A5F + [char]0x80FD + [char]0x3092 + [char]0x76F4 + `
    [char]0x63A5 + [char]0x64CD + [char]0x4F5C + [char]0x3057 + [char]0x305F + `
    [char]0x304B + [char]0xFF1F + [char]0xFF08 + "evidence_ref" + `
    [char]0x5FC5 + [char]0x9808 + [char]0xFF09

# C2: ユーザーとしてこのアプリ/CLIを渡されて使えるか？
$GATE_C2 = "C2: " + [char]0x30E6 + [char]0x30FC + [char]0x30B6 + [char]0x30FC + `
    [char]0x3068 + [char]0x3057 + [char]0x3066 + [char]0x3053 + [char]0x306E + `
    [char]0x30A2 + [char]0x30D7 + [char]0x30EA + "/CLI" + [char]0x3092 + `
    [char]0x6E21 + [char]0x3055 + [char]0x308C + [char]0x3066 + [char]0x4F7F + `
    [char]0x3048 + [char]0x308B + [char]0x304B + [char]0xFF1F + [char]0xFF08 + `
    "evidence_ref" + [char]0x5FC5 + [char]0x9808 + [char]0xFF09

# C3: テスト計画の全項目にPASS/FAIL/SKIPが記入されているか？
$GATE_C3 = "C3: " + $JP_TEST + [char]0x8A08 + [char]0x753B + [char]0x306E + `
    [char]0x5168 + [char]0x9805 + [char]0x76EE + [char]0x306B + "PASS/FAIL/SKIP" + `
    [char]0x304C + [char]0x8A18 + [char]0x5165 + [char]0x3055 + [char]0x308C + `
    [char]0x3066 + [char]0x3044 + [char]0x308B + [char]0x304B + [char]0xFF1F + `
    [char]0xFF08 + "evidence_ref" + [char]0x5FC5 + [char]0x9808 + [char]0xFF09

# C4: 「ビルド成功」「テスト通過」だけで判断していないか？MCP制約で未検証の操作はないか？
$GATE_C4 = "C4: " + [char]0x300C + [char]0x30D3 + [char]0x30EB + [char]0x30C9 + `
    [char]0x6210 + [char]0x529F + [char]0x300D + [char]0x300C + $JP_TEST + `
    [char]0x901A + [char]0x904E + [char]0x300D + [char]0x3060 + [char]0x3051 + `
    [char]0x3067 + [char]0x5224 + [char]0x65AD + [char]0x3057 + [char]0x3066 + `
    [char]0x3044 + [char]0x306A + [char]0x3044 + [char]0x304B + [char]0xFF1F + `
    "MCP" + [char]0x5236 + [char]0x7D04 + [char]0x3067 + [char]0x672A + `
    [char]0x691C + [char]0x8A3C + [char]0x306E + [char]0x64CD + [char]0x4F5C + `
    [char]0x306F + [char]0x306A + [char]0x3044 + [char]0x304B + [char]0xFF1F + `
    [char]0xFF08 + "evidence_ref" + [char]0x5FC5 + [char]0x9808 + [char]0xFF09

# C5: 修正前に壊れていた操作が修正後に正しく動くことを確認したか？
$GATE_C5 = "C5: " + [char]0x4FEE + [char]0x6B63 + [char]0x524D + [char]0x306B + `
    [char]0x58CA + [char]0x308C + [char]0x3066 + [char]0x3044 + [char]0x305F + `
    [char]0x64CD + [char]0x4F5C + [char]0x304C + [char]0x4FEE + [char]0x6B63 + `
    [char]0x5F8C + [char]0x306B + [char]0x6B63 + [char]0x3057 + [char]0x304F + `
    [char]0x52D5 + [char]0x304F + [char]0x3053 + [char]0x3068 + [char]0x3092 + `
    [char]0x78BA + [char]0x8A8D + [char]0x3057 + [char]0x305F + [char]0x304B + `
    [char]0xFF1F + [char]0xFF08 + "evidence_ref" + [char]0x5FC5 + [char]0x9808 + [char]0xFF09

# C6: 受け入れ条件の全項目にテスト結果が紐付いているか？
$GATE_C6 = "C6: " + [char]0x53D7 + [char]0x3051 + [char]0x5165 + [char]0x308C + `
    [char]0x6761 + [char]0x4EF6 + [char]0x306E + [char]0x5168 + [char]0x9805 + `
    [char]0x76EE + [char]0x306B + $JP_TEST + [char]0x7D50 + [char]0x679C + `
    [char]0x304C + [char]0x7D10 + [char]0x4ED8 + [char]0x3044 + [char]0x3066 + `
    [char]0x3044 + [char]0x308B + [char]0x304B + [char]0xFF1F + [char]0xFF08 + `
    "evidence_ref" + [char]0x5FC5 + [char]0x9808 + [char]0xFF09

# Footer: confidence_gate_responseとしてC1-C6全問にanswer + evidence_refを含めて回答すること。
$GATE_FOOTER = "confidence_gate_response " + [char]0x3068 + [char]0x3057 + [char]0x3066 + `
    "C1-C6" + [char]0x5168 + [char]0x554F + [char]0x306B + "answer + evidence_ref" + `
    [char]0x3092 + [char]0x542B + [char]0x3081 + [char]0x3066 + [char]0x56DE + `
    [char]0x7B54 + [char]0x3059 + [char]0x308B + [char]0x3053 + [char]0x3068 + [char]0x3002

# ============================================================
# Main Flow
# ============================================================

try {
    Write-DebugLog "=== confidence_gate_hook started ==="

    # == Phase 0: Quick Exit ==

    if (-not $Test) {
        if (Test-Path $cooldownFile) {
            $lastRaw = Get-Content -Path $cooldownFile -Raw -ErrorAction SilentlyContinue
            $lastRun = [datetime]::MinValue
            if ([datetime]::TryParse($lastRaw, [ref]$lastRun)) {
                $elapsed = ((Get-Date) - $lastRun).TotalSeconds
                if ($elapsed -lt $CooldownSeconds) {
                    Write-DebugLog "Cooldown active ($([int]$elapsed)s < ${CooldownSeconds}s)"
                    exit 0
                }
            }
        }
    }

    # == Phase 1: stdin ==

    $inputText = $null

    if ($Test) {
        $inputText = @($input) -join "`n"
    } else {
        try {
            $stream = [Console]::OpenStandardInput()
            $ms = New-Object System.IO.MemoryStream
            $buf = New-Object byte[] 8192
            while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
                $ms.Write($buf, 0, $n)
            }
            $inputText = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
            $ms.Dispose()
            Write-DebugLog "Stdin read: $($inputText.Length) chars"
        } catch {
            Write-DebugLog "Stdin read failed: $_"
        }

        # fallback: shared stdin file from speak_jarvis.ps1 (with freshness check)
        if (-not $inputText -or $inputText.Trim().Length -eq 0) {
            $sharedPath = Join-Path $env:TEMP "claude_hook_stdin.json"
            if (Test-Path $sharedPath) {
                $age = ((Get-Date) - (Get-Item $sharedPath).LastWriteTime).TotalSeconds
                if ($age -le 10) {
                    $inputText = [System.IO.File]::ReadAllText($sharedPath, [System.Text.Encoding]::UTF8)
                    Write-DebugLog "Fallback to shared stdin: $($inputText.Length) chars (age=${age}s)"
                } else {
                    Write-DebugLog "Shared stdin too stale (${age}s > 10s)"
                }
            }
        }
    }

    if (-not $inputText -or $inputText.Trim().Length -eq 0) {
        Write-DebugLog "No stdin"
        exit 0
    }

    try {
        $data = $inputText | ConvertFrom-Json
    } catch {
        Write-DebugLog "JSON parse failed: $_"
        exit 0
    }

    $message = $data.last_assistant_message
    if (-not $message -or $message.Length -lt 200) {
        Write-DebugLog "No message or too short ($($message.Length) chars)"
        exit 0
    }

    Write-DebugLog "Message: $($message.Length) chars"

    # Keep head + tail (E2E tables often appear at the end of long messages)
    $target = $message
    if ($target.Length -gt 10000) {
        $head = $target.Substring(0, 5000)
        $tail = $target.Substring($target.Length - 5000)
        $target = $head + "`n...`n" + $tail
        Write-DebugLog "Truncated to head(5000)+tail(5000)"
    }

    # == Phase 2: Anti-loop ==

    # own gate text in message -> skip
    if ($target -match '\[CONFIDENCE GATE\]') {
        Write-DebugLog "Anti-loop: own gate text"
        exit 0
    }

    # gate response pattern: require C1-C6 answers with both "answer" AND "evidence_ref"
    # (stricter than before: plain mention of "confidence_gate_response" in explanation text won't trigger)
    $answeredNums = [regex]::Matches($target, '(?mi)^C([1-6])\s*[:]\s*\{?\s*answer') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $evidenceRefCount = ([regex]::Matches($target, 'evidence_ref')).Count

    if ($answeredNums.Count -ge 4 -and $evidenceRefCount -ge 4) {
        Write-DebugLog "Anti-loop: gate response (answered=C$($answeredNums -join ',C'), refs=$evidenceRefCount)"
        exit 0
    }

    # == Phase 3: E2E report detection (weighted scoring) ==

    $score = 0
    $details = @()

    # --- Category A (weight 3): Strong signals ---

    # A1: test result table rows (T1 | ... | PASS)
    $a1 = ([regex]::Matches($target, '(?mi)^\s*\|?\s*T\d{1,2}\s*\|.*?\b(PASS|FAIL|SKIP)\b')).Count
    if ($a1 -ge 2) {
        $score += 3; $details += "A1:3(rows=$a1)"
    }

    # A2: "e2e_result" JSON key
    if ($target -match '"e2e_result"\s*:\s*"?(PASS|FAIL)') {
        $score += 3; $details += "A2:3"
    }

    # A3: "confidence_gate" JSON structure in report
    if ($target -match '"confidence_gate"\s*:\s*\{' -and $target -match '"C[1-6]"') {
        $score += 3; $details += "A3:3"
    }

    # A4: summary with pass/fail/skip counts
    if ($target -match '"summary"\s*:\s*\{' -and $target -match '"(passed|failed|skipped)"\s*:\s*\d') {
        $score += 3; $details += "A4:3"
    }

    # --- Category B (weight 2): Medium signals ---

    # B1: Japanese test completion phrases
    if ($target.Contains($JP_TEST_RESULT) -or $target.Contains($JP_TEST_COMPLETE) -or
        $target.Contains($JP_TEST_REPORT) -or $target.Contains($JP_E2E_RESULT)) {
        $score += 2; $details += "B1:2"
    }

    # B2: Playwright summary ("X passed")
    if ($target -match '\d+\s+passed') {
        $score += 2; $details += "B2:2"
    }

    # B3: core_operation / deploy_verification JSON keys
    if ($target -match '"(core_operation|deploy_verification)"\s*:') {
        $score += 2; $details += "B3:2"
    }

    # B4: Phase 3/B + test vocabulary (strict: number/letter must follow "Phase"/"フェーズ" directly)
    $hasPhase = ($target -match 'Phase\s*[3B]\b') -or ($target -match ($JP_PHASE + '\s*[3B]'))
    $hasTestWord = $target.Contains($JP_TEST) -or ($target -match '\b(test|E2E|PASS|FAIL)\b')
    if ($hasPhase -and $hasTestWord) {
        $score += 2; $details += "B4:2"
    }

    # --- Category C (weight 1): Weak signals ---

    # C-1: test IDs (T1-T9) >= 3
    $idCount = ([regex]::Matches($target, '\bT[1-9]\b')).Count
    if ($idCount -ge 3) {
        $score += 1; $details += "Cw1:1(ids=$idCount)"
    }

    # C-2: PASS/FAIL >= 2
    $verdictCount = ([regex]::Matches($target, '\b(PASS|FAIL)\b')).Count
    if ($verdictCount -ge 2) {
        $score += 1; $details += "Cw2:1(v=$verdictCount)"
    }

    # C-3: E2E >= 3 mentions
    $e2eCount = ([regex]::Matches($target, '(?i)\bE2E\b')).Count
    if ($e2eCount -ge 3) {
        $score += 1; $details += "Cw3:1(e2e=$e2eCount)"
    }

    # C-4: user_perspective_check key
    if ($target -match '"?user_perspective_check"?\s*:') {
        $score += 1; $details += "Cw4:1"
    }

    # --- Negative (weight -2) ---

    # N1: test plan without results
    if ($target.Contains($JP_TEST_PLAN) -and $verdictCount -eq 0) {
        $score -= 2; $details += "N1:-2"
    }

    # N2: Phase 1 without results (strict: "1" must follow "Phase"/"フェーズ" directly)
    $hasP1 = ($target -match 'Phase\s*1\b') -or ($target -match ($JP_PHASE + '\s*1\b'))
    if ($hasP1 -and -not ($target -match '"e2e_result"')) {
        $score -= 2; $details += "N2:-2"
    }

    $detailStr = if ($details.Count -gt 0) { $details -join ", " } else { "none" }
    Write-DebugLog "Score: $score / $ScoreThreshold [$detailStr]"

    # == Test mode output ==
    if ($Test) {
        Write-Output "Score: $score / threshold: $ScoreThreshold"
        Write-Output "Details: $detailStr"
        Write-Output ("Result: " + $(if ($score -ge $ScoreThreshold) { "WOULD TRIGGER" } else { "would NOT trigger" }))
        exit 0
    }

    if ($score -lt $ScoreThreshold) {
        exit 0
    }

    # == Phase 4: Inject gate ==

    Write-DebugLog "TRIGGERING (score=$score)"

    # Write raw UTF-8 bytes directly to stdout stream
    # (PowerShell ignores [Console]::OutputEncoding when stdout is redirected)
    $gateLines = @(
        $GATE_LINE1,
        $GATE_LINE2,
        $GATE_LINE3,
        "",
        $GATE_C1,
        $GATE_C2,
        $GATE_C3,
        $GATE_C4,
        $GATE_C5,
        $GATE_C6,
        "",
        $GATE_FOOTER
    )
    $gateText = ($gateLines -join "`n") + "`n"
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($gateText)
    $stdout = [Console]::OpenStandardOutput()
    $stdout.Write($utf8Bytes, 0, $utf8Bytes.Length)
    $stdout.Flush()

    # Write cooldown AFTER successful stdout flush (not before)
    (Get-Date).ToString("o") | Set-Content -Path $cooldownFile -Encoding ascii

    Write-DebugLog "Gate output: $($gateText.Length) chars, $($utf8Bytes.Length) UTF-8 bytes"

    exit 0

} catch {
    if ($Debug -or $Test) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        "[$timestamp] [gate] ERROR: $_" | Out-File -FilePath $debugLog -Append -Encoding utf8
    }
    exit 0
}
