# focus_terminal.ps1 - Toast notification click handler
#
# Receives claude-focus://HWND URI from Windows protocol handler
# and brings the specified terminal window to foreground.
#
# Called automatically when user clicks a Claude Code toast notification.

param(
    [Parameter(Position=0)]
    [string]$Uri
)

$ErrorActionPreference = "SilentlyContinue"

if (-not $Uri) { exit 0 }

# Parse URI: claude-focus://HWND or claude-focus://HWND/
$hwndStr = $Uri -replace '^claude-focus://?', '' -replace '[/\\]$', ''
if (-not $hwndStr -or $hwndStr -notmatch '^\d+$') { exit 0 }

$hwndInt = [IntPtr]::new([long]$hwndStr)
if ($hwndInt -eq [IntPtr]::Zero) { exit 0 }

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinFocus {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    public const int SW_RESTORE = 9;
    public const byte VK_MENU = 0x12;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    public static void ForceForeground(IntPtr hWnd) {
        if (!IsWindow(hWnd)) return;

        if (IsIconic(hWnd)) {
            ShowWindow(hWnd, SW_RESTORE);
        }

        // Simulate Alt key press to bypass SetForegroundWindow restrictions
        keybd_event(VK_MENU, 0, 0, UIntPtr.Zero);
        SetForegroundWindow(hWnd);
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}
"@

[WinFocus]::ForceForeground($hwndInt)

exit 0
