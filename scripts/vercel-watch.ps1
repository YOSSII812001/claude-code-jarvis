# vercel-watch.ps1
# Vercel デプロイ状況リアルタイム監視スクリプト
#
# 使い方:
#   powershell -File vercel-watch.ps1                          # デフォルト（10秒間隔、無限ループ）
#   powershell -File vercel-watch.ps1 -WaitForReady            # Ready検知後に自動終了（推奨）
#   powershell -File vercel-watch.ps1 -Interval 5              # 5秒間隔
#   powershell -File vercel-watch.ps1 -Once                    # 一回だけ確認
#   powershell -File vercel-watch.ps1 -Project "my-app"        # プロジェクト指定
#   powershell -File vercel-watch.ps1 -Environment Production  # 本番のみ監視
#
# 注意: Claude Code内で run_in_background で使う場合は必ず -WaitForReady を付けること。
#       付けないとプロセスが終了せず、TaskOutputがブロックされる。

param(
    [string]$Project = "digital-management-consulting-app",
    [int]$Interval = 10,
    [switch]$Once,
    [switch]$WaitForReady,
    [ValidateSet("All", "Production", "Preview")]
    [string]$Environment = "All"
)

# --- ANSI カラー定義 ---
$Colors = @{
    Green  = "`e[32m"
    Yellow = "`e[33m"
    Red    = "`e[31m"
    Cyan   = "`e[36m"
    Gray   = "`e[90m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

# --- デプロイ情報のパース ---
function Get-DeploymentList {
    param([string]$ProjectName)

    $raw = vercel ls $ProjectName 2>&1 | Out-String
    $lines = $raw -split "`n" | Where-Object { $_ -match "https://" }

    $deployments = @()
    foreach ($line in $lines) {
        # 2つ以上の空白で分割（● 文字のエンコーディング問題を回避）
        $parts = $line.Trim() -split "\s{2,}"
        if ($parts.Count -ge 4) {
            # parts[2] から既知のステータス名を抽出（壊れた●プレフィックスを除去）
            $statusRaw = $parts[2]
            $status = if ($statusRaw -match "(Ready|Building|Error|Canceled)") { $Matches[1] } else { $statusRaw }

            $deployments += [PSCustomObject]@{
                Age         = $parts[0]
                Url         = $parts[1]
                Status      = $status
                Environment = $parts[3]
                Duration    = if ($parts.Count -ge 5) { $parts[4] } else { "--" }
                User        = if ($parts.Count -ge 6) { $parts[5] } else { "unknown" }
            }
        }
    }
    return $deployments
}

function Compare-DeploymentStatus {
    param(
        [array]$Current,
        [array]$Previous
    )

    # 初回実行時はBuildingがあれば通知
    if ($null -eq $Previous) {
        $building = $Current | Where-Object { $_.Status -eq "Building" }
        if ($building.Count -gt 0) {
            $msgs = @()
            foreach ($b in $building) {
                $envTag = if ($b.Environment -eq "Production") { "$($Colors.Red)[PROD]$($Colors.Reset)" } else { "[Preview]" }
                $msgs += "$($Colors.Yellow)$envTag ビルド検出: $($b.Status)$($Colors.Reset)"
            }
            return @{ Changed = $true; Messages = $msgs }
        }
        return @{ Changed = $false; Messages = @() }
    }

    # URLをキーにした前回ステータスのルックアップテーブル
    $prevMap = @{}
    foreach ($p in $Previous) {
        $prevMap[$p.Url] = $p
    }

    $messages = @()

    foreach ($cur in $Current) {
        $prev = $prevMap[$cur.Url]
        $envTag = if ($cur.Environment -eq "Production") { "$($Colors.Red)[PROD]$($Colors.Reset)" } else { "$($Colors.Gray)[Preview]$($Colors.Reset)" }

        if ($null -eq $prev) {
            # 新しいデプロイが出現
            $messages += "$($Colors.Cyan)$envTag 新規デプロイ開始: $($cur.Status)$($Colors.Reset)"
        }
        elseif ($prev.Status -ne $cur.Status) {
            # ステータスが変化した
            switch ($cur.Status) {
                "Ready" {
                    $messages += "$($Colors.Green)$envTag デプロイ成功! ($($prev.Status) -> Ready, $($cur.Duration))$($Colors.Reset)"
                }
                "Error" {
                    $messages += "$($Colors.Red)$envTag デプロイ失敗! ($($prev.Status) -> Error)$($Colors.Reset)"
                }
                "Canceled" {
                    $messages += "$($Colors.Gray)$envTag デプロイキャンセル ($($prev.Status) -> Canceled)$($Colors.Reset)"
                }
                default {
                    $messages += "$envTag ステータス変更: $($prev.Status) -> $($cur.Status)"
                }
            }
        }
    }

    # Production の変更を先頭に（重要度順ソート）
    $prodMsgs = $messages | Where-Object { $_ -match "\[PROD\]" }
    $otherMsgs = $messages | Where-Object { $_ -notmatch "\[PROD\]" }
    $sorted = @()
    if ($prodMsgs) { $sorted += $prodMsgs }
    if ($otherMsgs) { $sorted += $otherMsgs }

    return @{ Changed = ($sorted.Count -gt 0); Messages = $sorted }
}

# --- 表示フォーマット ---
function Show-DeploymentTable {
    param([array]$Deployments, [string]$Env)

    $filtered = if ($Env -eq "All") { $Deployments } else {
        $Deployments | Where-Object { $_.Environment -eq $Env }
    }

    $header = "$($Colors.Bold)  Status     Environment   Age      Duration   URL$($Colors.Reset)"
    Write-Host $header
    Write-Host "$($Colors.Gray)  ──────────────────────────────────────────────────────────────────────$($Colors.Reset)"

    foreach ($d in $filtered) {
        $statusColor = switch ($d.Status) {
            "Ready"    { $Colors.Green }
            "Building" { $Colors.Yellow }
            "Error"    { $Colors.Red }
            "Canceled" { $Colors.Gray }
            default    { $Colors.Reset }
        }
        $envLabel = if ($d.Environment -eq "Production") {
            "$($Colors.Cyan)Production$($Colors.Reset)"
        } else {
            "$($Colors.Gray)Preview   $($Colors.Reset)"
        }

        $statusIcon = switch ($d.Status) {
            "Ready"    { "+" }
            "Building" { "~" }
            "Error"    { "x" }
            "Canceled" { "-" }
            default    { "?" }
        }
        $shortUrl = $d.Url -replace 'https://digital-management-consulting-', '' -replace '-robbits0802\.vercel\.app', ''
        Write-Host "  $statusColor[$statusIcon] $($d.Status.PadRight(10))$($Colors.Reset) $envLabel  $($d.Age.PadRight(8)) $($d.Duration.PadRight(10)) $($Colors.Gray)...$shortUrl$($Colors.Reset)"
    }
}

# --- ビープ通知はStopフックが自動処理（手動呼び出し不要） ---

# --- メイン監視ループ ---
function Start-Monitoring {
    $previousDeployments = $null
    $sawBuilding = $false
    $checksWithoutBuilding = 0

    $modeLabel = if ($WaitForReady) { "WaitForReady" } elseif ($Once) { "Once" } else { "Continuous" }

    Write-Host ""
    Write-Host "$($Colors.Bold)$($Colors.Cyan)  Vercel Deploy Watcher$($Colors.Reset)"
    Write-Host "$($Colors.Gray)  Project: $Project | Interval: ${Interval}s | Filter: $Environment | Mode: $modeLabel$($Colors.Reset)"
    if (-not $WaitForReady -and -not $Once) {
        Write-Host "$($Colors.Gray)  Ctrl+C で終了$($Colors.Reset)"
    }
    Write-Host ""

    while ($true) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "$($Colors.Gray)  [$timestamp] Checking...$($Colors.Reset)" -NoNewline

        $current = Get-DeploymentList -ProjectName $Project

        if ($current.Count -eq 0) {
            Write-Host "`r$($Colors.Red)  [$timestamp] デプロイ情報の取得に失敗しました$($Colors.Reset)"
        } else {
            # 環境フィルタ適用
            $filtered = if ($Environment -eq "All") { $current } else {
                $current | Where-Object { $_.Environment -eq $Environment }
            }

            # 画面クリア（前の結果を上書き）
            Write-Host "`r"
            Write-Host "$($Colors.Gray)  [$timestamp] $($current.Count) deployments found$($Colors.Reset)"
            Show-DeploymentTable -Deployments $current -Env $Environment

            # ステータス変更チェック
            $result = Compare-DeploymentStatus -Current $current -Previous $previousDeployments
            if ($result.Changed) {
                Write-Host ""
                foreach ($msg in $result.Messages) {
                    Write-Host "  $($Colors.Bold)>> $msg$($Colors.Reset)"
                }
                # ビープ通知はStopフックが自動処理するため、ここでは鳴らさない
            }

            $previousDeployments = $current

            # -WaitForReady モード: Building検知後、全てReady/Error/Canceledになったら自動終了
            if ($WaitForReady) {
                # @() で配列化（スカラー返却時の .Count 問題を回避）
                $buildingCount = @($filtered | Where-Object { $_.Status -eq "Building" }).Count
                if ($buildingCount -gt 0) {
                    $sawBuilding = $true
                    $checksWithoutBuilding = 0
                } else {
                    $checksWithoutBuilding++
                }
                # パターン1: Building→Ready遷移を検知して終了
                if ($sawBuilding -and $buildingCount -eq 0) {
                    $readyCount = @($filtered | Where-Object { $_.Status -eq "Ready" }).Count
                    $errorCount = @($filtered | Where-Object { $_.Status -eq "Error" }).Count
                    Write-Host ""
                    Write-Host "$($Colors.Green)$($Colors.Bold)  All deployments finished! (Ready: $readyCount, Error: $errorCount)$($Colors.Reset)"
                    if ($errorCount -gt 0) { exit 1 }
                    exit 0
                }
                # パターン2: 3回連続でBuildingなし → デプロイ済みと判断して終了
                if (-not $sawBuilding -and $checksWithoutBuilding -ge 3) {
                    $readyCount = @($filtered | Where-Object { $_.Status -eq "Ready" }).Count
                    Write-Host ""
                    Write-Host "$($Colors.Yellow)$($Colors.Bold)  No Building deployments detected after $checksWithoutBuilding checks. All Ready ($readyCount). Exiting.$($Colors.Reset)"
                    exit 0
                }
            }
        }

        if ($Once) { break }

        Write-Host ""
        Write-Host "$($Colors.Gray)  Next check in ${Interval}s...$($Colors.Reset)"
        Start-Sleep -Seconds $Interval
        # 画面クリア
        Clear-Host
    }
}

# 実行
Start-Monitoring
