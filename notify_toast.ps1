# notify_toast.ps1 - Windows Toast通知でClaudeの応答を表示
#
# Claude Code Stop Hook から自動実行される
# speak_jarvis.ps1 と並列動作（音声 + Toast通知の二重通知）
#
# パラメータ:
#   -MaxLength : 通知に表示する最大文字数（デフォルト: 120）
#   -Debug     : デバッグログ出力

param(
    [switch]$Debug,
    [int]$MaxLength = 120
)

$ErrorActionPreference = "SilentlyContinue"
$toastLog = Join-Path $env:TEMP "toast_debug.log"

function Write-DebugLog {
    param([string]$Message)
    if ($Debug) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        "[$timestamp] [toast] $Message" | Out-File -FilePath $toastLog -Append -Encoding utf8
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
    return $Text.Trim()
}

Write-DebugLog "=== notify_toast started ==="

try {
    # stdin JSON 読み取り（rawバイト→UTF-8デコードで文字化け防止）
    $inputText = $null
    try {
        $stream = [Console]::OpenStandardInput()
        $ms = New-Object System.IO.MemoryStream
        $buffer = New-Object byte[] 8192
        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $ms.Write($buffer, 0, $bytesRead)
        }
        $inputText = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
        $ms.Dispose()
        Write-DebugLog "Stdin read (raw): $($inputText.Length) chars"
    } catch {
        Write-DebugLog "Stdin raw read failed: $_"
    }

    # speak_jarvis.ps1が先にstdinを消費した場合のフォールバック
    if (-not $inputText -or $inputText.Trim().Length -eq 0) {
        $sharedStdinPath = Join-Path $env:TEMP "claude_hook_stdin.json"
        if (Test-Path $sharedStdinPath) {
            $inputText = [System.IO.File]::ReadAllText($sharedStdinPath, [System.Text.Encoding]::UTF8)
            Write-DebugLog "Read from shared stdin file: $($inputText.Length) chars"
        }
    }
    if (-not $inputText -or $inputText.Trim().Length -eq 0) {
        Write-DebugLog "No stdin received (neither pipe nor shared file)"
        exit 0
    }

    $data = $inputText | ConvertFrom-Json
    $message = $data.last_assistant_message
    if (-not $message -or $message.Length -eq 0) {
        Write-DebugLog "No last_assistant_message"
        exit 0
    }

    # テキスト整形
    $cleanText = Remove-Markdown -Text $message
    if ($cleanText.Length -eq 0) {
        Write-DebugLog "Empty after cleaning"
        exit 0
    }

    # 先頭行をタイトルに、残りをボディに（日本語句読点はchar codeでBOM非依存）
    $splitPattern = "[.!?" + [char]0x3002 + [char]0xFF01 + [char]0xFF1F + "]"
    $lines = @($cleanText -split $splitPattern | Where-Object { $_.Trim().Length -gt 0 })
    if ($lines.Count -gt 0) {
        $title = $lines[0].Trim()
        if ($title.Length -gt 60) {
            $title = $title.Substring(0, 57) + "..."
        }
    } else {
        $title = "Claude Code"
    }

    if ($cleanText.Length -gt $MaxLength) {
        $body = $cleanText.Substring(0, $MaxLength) + "..."
    } else {
        $body = $cleanText
    }

    Write-DebugLog "Title: $title"
    Write-DebugLog "Body: $body"

    # BurntToast 通知（ウサコンアイコン付き）
    Import-Module BurntToast -ErrorAction Stop

    $iconPath = Join-Path $PSScriptRoot "usacon_toast_icon.png"
    if (Test-Path $iconPath) {
        New-BurntToastNotification -Text "Claude Code", $body -AppLogo $iconPath -ErrorAction Stop
    } else {
        New-BurntToastNotification -Text "Claude Code", $body -ErrorAction Stop
    }

    Write-DebugLog "Toast notification sent"
    Write-DebugLog "=== notify_toast complete ==="

} catch {
    Write-DebugLog "Error: $($_.Exception.Message)"
    Write-DebugLog "Stack: $($_.ScriptStackTrace)"
}

exit 0
