# voicevox-dict-helper.ps1 - VOICEVOX辞書管理ヘルパースクリプト
#
# Usage:
#   -Action List          : 登録済み単語一覧
#   -Action Register      : 単語登録（-Surface, -Pronunciation, -AccentType 必須）
#   -Action BulkRegister  : スターター辞書一括登録（冪等）
#   -Action Delete        : 単語削除（-Surface で指定）
#   -Action Search        : 単語検索（-Surface で部分一致）
#   -Action Backup        : 辞書バックアップ（JSON）
#   -Action Restore       : 辞書リストア（-BackupFile 必須）
#   -Action Test          : 発音テスト（-Surface で指定、VOICEVOX合成再生）

param(
    [ValidateSet("List", "Register", "BulkRegister", "Delete", "Search", "Backup", "Restore", "Test")]
    [string]$Action = "List",
    [string]$Surface = "",
    [string]$Pronunciation = "",
    [int]$AccentType = 0,
    [string]$WordType = "PROPER_NOUN",
    [int]$Priority = 5,
    [string]$BackupFile = "",
    [string]$VoicevoxUrl = "http://127.0.0.1:50021",
    [int]$SpeakerId = 21,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

# HttpClient assembly for reliable UTF-8 handling
Add-Type -AssemblyName System.Net.Http
# VisualBasic for StrConv (full-width normalization matching VOICEVOX Engine)
Add-Type -AssemblyName Microsoft.VisualBasic

# ============================================================
# 共通関数
# ============================================================

function Test-VoicevoxConnection {
    try {
        $null = Invoke-RestMethod -Uri ($VoicevoxUrl + "/version") -Method Get -TimeoutSec 3
        return $true
    } catch {
        return $false
    }
}

function Convert-ToVoicevoxSurface {
    # VOICEVOX Engine normalizes surface to full-width on registration.
    # This function replicates that normalization for accurate comparison.
    param([Parameter(Mandatory)][string]$Surface)
    $kc = $Surface.Normalize([System.Text.NormalizationForm]::FormKC)
    return [Microsoft.VisualBasic.Strings]::StrConv(
        $kc,
        [Microsoft.VisualBasic.VbStrConv]::Wide,
        0x411
    )
}

function Get-UserDict {
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    try {
        $client.Timeout = [TimeSpan]::FromSeconds(10)
        $resp = $client.GetAsync("$VoicevoxUrl/user_dict").GetAwaiter().GetResult()
        $resp.EnsureSuccessStatusCode()
        $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        return $json | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "[ERROR] Failed to get user dictionary: $_" -ForegroundColor Red
        return $null
    } finally {
        $client.Dispose()
        $handler.Dispose()
    }
}

function Show-DictTable {
    param($Dict)
    if (-not $Dict) {
        Write-Host "(empty dictionary)" -ForegroundColor Yellow
        return
    }

    $entries = @()
    foreach ($prop in $Dict.PSObject.Properties) {
        $uuid = $prop.Name
        $word = $prop.Value
        $entries += [PSCustomObject]@{
            Surface       = $word.surface
            Pronunciation = $word.pronunciation
            AccentType    = $word.accent_type
            WordType      = $word.part_of_speech_detail_1
            Priority      = $word.priority
            UUID          = $uuid.Substring(0, 8) + "..."
        }
    }

    if ($entries.Count -eq 0) {
        Write-Host "(empty dictionary)" -ForegroundColor Yellow
        return
    }

    $entries | Sort-Object Surface | Format-Table -AutoSize
    Write-Host "Total: $($entries.Count) words" -ForegroundColor Cyan
}

function Find-WordBySubsurface {
    param($Dict, [string]$SearchSurface)
    $results = @()
    if (-not $Dict) { return $results }
    # Normalize search term to match VOICEVOX Engine's full-width storage
    $normalizedSearch = Convert-ToVoicevoxSurface $SearchSurface
    foreach ($prop in $Dict.PSObject.Properties) {
        if ($prop.Value.surface -like "*$normalizedSearch*") {
            $results += [PSCustomObject]@{
                UUID          = $prop.Name
                Surface       = $prop.Value.surface
                Pronunciation = $prop.Value.pronunciation
                AccentType    = $prop.Value.accent_type
            }
        }
    }
    return $results
}

# ============================================================
# スターター辞書（IT用語 + プロジェクト固有語）
# ============================================================

$StarterDict = @(
    # === プログラミング言語・フレームワーク ===
    @{ surface="TypeScript";    pronunciation="タイプスクリプト";     accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="JavaScript";    pronunciation="ジャバスクリプト";     accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="Python";        pronunciation="パイソン";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="React";         pronunciation="リアクト";             accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Next.js";       pronunciation="ネクストジェーエス";   accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="Node.js";       pronunciation="ノードジェーエス";     accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="Vue";           pronunciation="ビュー";               accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Svelte";        pronunciation="スベルト";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Nuxt";          pronunciation="ナクスト";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Remix";         pronunciation="リミックス";           accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Astro";         pronunciation="アストロ";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Tailwind";      pronunciation="テイルウインド";       accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Vite";          pronunciation="ヴィート";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Prisma";        pronunciation="プリズマ";             accent_type=1; word_type="PROPER_NOUN" }

    # === プラットフォーム・サービス ===
    @{ surface="GitHub";        pronunciation="ギットハブ";           accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Vercel";        pronunciation="バーセル";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Supabase";      pronunciation="スーパベース";         accent_type=4; word_type="PROPER_NOUN" }
    @{ surface="Docker";        pronunciation="ドッカー";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Kubernetes";    pronunciation="クーバネティス";       accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="Redis";         pronunciation="レディス";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="PostgreSQL";    pronunciation="ポストグレスキューエル"; accent_type=7; word_type="PROPER_NOUN" }
    @{ surface="Stripe";        pronunciation="ストライプ";           accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Clerk";         pronunciation="クラーク";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="OAuth";         pronunciation="オーオース";           accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="GraphQL";       pronunciation="グラフキューエル";     accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="Terraform";     pronunciation="テラフォーム";         accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Turborepo";     pronunciation="ターボレポ";           accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Turbopack";     pronunciation="ターボパック";         accent_type=3; word_type="PROPER_NOUN" }

    # === ツール・ライブラリ ===
    @{ surface="ESLint";        pronunciation="イーエスリント";       accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="Prettier";      pronunciation="プリティアー";         accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="Webpack";       pronunciation="ウェブパック";         accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="FFmpeg";        pronunciation="エフエフエムペグ";     accent_type=7; word_type="PROPER_NOUN" }
    @{ surface="Playwright";    pronunciation="プレイライト";         accent_type=3; word_type="PROPER_NOUN" }
    @{ surface="shadcn";        pronunciation="シャドシーエヌ";       accent_type=3; word_type="PROPER_NOUN" }

    # === アクロニム・略語 ===
    @{ surface="API";           pronunciation="エーピーアイ";         accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="CLI";           pronunciation="シーエルアイ";         accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="CI";            pronunciation="シーアイ";             accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="CD";            pronunciation="シーディー";           accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="PR";            pronunciation="ピーアール";           accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="SSE";           pronunciation="エスエスイー";         accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="JWT";           pronunciation="ジェーダブリューティー"; accent_type=7; word_type="COMMON_NOUN" }
    @{ surface="REST";          pronunciation="レスト";               accent_type=1; word_type="COMMON_NOUN" }
    @{ surface="RLS";           pronunciation="アールエルエス";       accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="MUI";           pronunciation="エムユーアイ";         accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="ORM";           pronunciation="オーアールエム";       accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="npm";           pronunciation="エヌピーエム";         accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="k8s";           pronunciation="ケーエイツ";           accent_type=3; word_type="PROPER_NOUN" }

    # === 技術用語 ===
    @{ surface="middleware";     pronunciation="ミドルウェア";         accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="deployment";    pronunciation="デプロイメント";       accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="repository";    pronunciation="リポジトリ";           accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="Webhook";       pronunciation="ウェブフック";         accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="rollback";      pronunciation="ロールバック";         accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="refactoring";   pronunciation="リファクタリング";     accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="throttling";    pronunciation="スロットリング";       accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="caching";       pronunciation="キャッシング";         accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="linting";       pronunciation="リンティング";         accent_type=3; word_type="COMMON_NOUN" }
    @{ surface="monorepo";      pronunciation="モノレポ";             accent_type=1; word_type="COMMON_NOUN" }

    # === AI・Claude関連 ===
    @{ surface="Claude";        pronunciation="クロード";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Anthropic";     pronunciation="アンスロピック";       accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="VOICEVOX";      pronunciation="ボイスボックス";       accent_type=5; word_type="PROPER_NOUN" }
    @{ surface="JARVIS";        pronunciation="ジャービス";           accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="LLM";           pronunciation="エルエルエム";         accent_type=5; word_type="COMMON_NOUN" }
    @{ surface="RAG";           pronunciation="ラグ";                 accent_type=1; word_type="COMMON_NOUN" }

    # === プロジェクト固有 ===
    @{ surface="Usacon";        pronunciation="ウサコン";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="Robbits";       pronunciation="ロビッツ";             accent_type=1; word_type="PROPER_NOUN" }
    @{ surface="gBizINFO";      pronunciation="ジービズインフォ";     accent_type=5; word_type="PROPER_NOUN" }
)

# ============================================================
# Action 実装
# ============================================================

# 接続チェック（全Actionで必須）
if (-not (Test-VoicevoxConnection)) {
    Write-Host "[ERROR] VOICEVOX is not running at $VoicevoxUrl" -ForegroundColor Red
    Write-Host "Start VOICEVOX first, or check the URL." -ForegroundColor Yellow
    exit 1
}

switch ($Action) {

    "List" {
        Write-Host "=== VOICEVOX User Dictionary ===" -ForegroundColor Cyan
        $dict = Get-UserDict
        Show-DictTable -Dict $dict
    }

    "Register" {
        if (-not $Surface -or -not $Pronunciation) {
            Write-Host "[ERROR] -Surface and -Pronunciation are required for Register" -ForegroundColor Red
            exit 1
        }
        $encodedSurface = [uri]::EscapeDataString($Surface)
        $encodedPronunciation = [uri]::EscapeDataString($Pronunciation)
        $uri = "{0}/user_dict_word?surface={1}&pronunciation={2}&accent_type={3}&word_type={4}&priority={5}" -f $VoicevoxUrl, $encodedSurface, $encodedPronunciation, $AccentType, $WordType, $Priority
        try {
            $uuid = Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 5
            Write-Host "[OK] Registered: $Surface -> $Pronunciation (accent=$AccentType, uuid=$uuid)" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Failed to register '$Surface': $_" -ForegroundColor Red
        }
    }

    "BulkRegister" {
        Write-Host "=== Bulk Register Starter Dictionary ===" -ForegroundColor Cyan
        $dict = Get-UserDict
        $existingSurfaces = @{}
        if ($dict) {
            foreach ($prop in $dict.PSObject.Properties) {
                # Store as-is (Engine returns full-width normalized surface)
                $existingSurfaces[$prop.Value.surface] = $prop.Name
            }
        }

        $registered = 0; $skipped = 0; $errors = 0

        foreach ($entry in $StarterDict) {
            $s = $entry.surface
            $normalizedS = Convert-ToVoicevoxSurface $s
            if ($existingSurfaces.ContainsKey($normalizedS) -and -not $Force) {
                Write-Host "  [SKIP] $s (already registered)" -ForegroundColor DarkGray
                $skipped++
                continue
            }

            # -Force: 既存エントリがあればPUTで更新
            if ($existingSurfaces.ContainsKey($normalizedS) -and $Force) {
                $existingUuid = $existingSurfaces[$normalizedS]
                $encodedSurface = [uri]::EscapeDataString($s)
                $encodedPron = [uri]::EscapeDataString($entry.pronunciation)
                $uri = "{0}/user_dict_word/{1}?surface={2}&pronunciation={3}&accent_type={4}&word_type={5}&priority={6}" -f $VoicevoxUrl, $existingUuid, $encodedSurface, $encodedPron, $entry.accent_type, $entry.word_type, $Priority
                try {
                    Invoke-RestMethod -Uri $uri -Method Put -TimeoutSec 5 | Out-Null
                    Write-Host "  [UPDATE] $s -> $($entry.pronunciation)" -ForegroundColor Yellow
                    $registered++
                } catch {
                    Write-Host "  [ERROR] $s : $_" -ForegroundColor Red
                    $errors++
                }
                continue
            }

            $encodedSurface = [uri]::EscapeDataString($s)
            $encodedPron = [uri]::EscapeDataString($entry.pronunciation)
            $uri = "{0}/user_dict_word?surface={1}&pronunciation={2}&accent_type={3}&word_type={4}&priority={5}" -f $VoicevoxUrl, $encodedSurface, $encodedPron, $entry.accent_type, $entry.word_type, $Priority
            try {
                $null = Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 5
                Write-Host "  [OK] $s -> $($entry.pronunciation)" -ForegroundColor Green
                $registered++
            } catch {
                Write-Host "  [ERROR] $s : $_" -ForegroundColor Red
                $errors++
            }
        }

        Write-Host ""
        Write-Host "--- Summary ---" -ForegroundColor Cyan
        Write-Host "  Registered: $registered" -ForegroundColor Green
        Write-Host "  Skipped:    $skipped" -ForegroundColor DarkGray
        Write-Host "  Errors:     $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "DarkGray" })
    }

    "Delete" {
        if (-not $Surface) {
            Write-Host "[ERROR] -Surface is required for Delete" -ForegroundColor Red
            exit 1
        }
        $dict = Get-UserDict
        $found = Find-WordBySubsurface -Dict $dict -SearchSurface $Surface
        if ($found.Count -eq 0) {
            Write-Host "[WARN] No entry found matching '$Surface'" -ForegroundColor Yellow
            exit 0
        }
        foreach ($item in $found) {
            try {
                $uri = "{0}/user_dict_word/{1}" -f $VoicevoxUrl, $item.UUID
                Invoke-RestMethod -Uri $uri -Method Delete -TimeoutSec 5 | Out-Null
                Write-Host "[OK] Deleted: $($item.Surface) (uuid=$($item.UUID.Substring(0,8))...)" -ForegroundColor Green
            } catch {
                Write-Host "[ERROR] Failed to delete $($item.Surface): $_" -ForegroundColor Red
            }
        }
    }

    "Search" {
        if (-not $Surface) {
            Write-Host "[ERROR] -Surface is required for Search" -ForegroundColor Red
            exit 1
        }
        $dict = Get-UserDict
        $found = Find-WordBySubsurface -Dict $dict -SearchSurface $Surface
        if ($found.Count -eq 0) {
            Write-Host "No entries matching '$Surface'" -ForegroundColor Yellow
        } else {
            $found | Format-Table -AutoSize
            Write-Host "Found: $($found.Count) entries" -ForegroundColor Cyan
        }
    }

    "Backup" {
        $backupDir = Join-Path $PSScriptRoot "backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = Join-Path $backupDir "voicevox_dict_$timestamp.json"

        try {
            $wc = New-Object System.Net.WebClient
            $wc.Encoding = [System.Text.Encoding]::UTF8
            $json = $wc.DownloadString($VoicevoxUrl + "/user_dict")
            $wc.Dispose()
            [System.IO.File]::WriteAllText($backupPath, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "[OK] Backup saved: $backupPath" -ForegroundColor Green

            # Count entries
            $dict = $json | ConvertFrom-Json
            $count = @($dict.PSObject.Properties).Count
            Write-Host "  Entries: $count words" -ForegroundColor Cyan
        } catch {
            Write-Host "[ERROR] Backup failed: $_" -ForegroundColor Red
        }
    }

    "Restore" {
        if (-not $BackupFile -or -not (Test-Path $BackupFile)) {
            Write-Host "[ERROR] -BackupFile is required and must exist" -ForegroundColor Red
            if (-not $BackupFile) {
                $backupDir = Join-Path $PSScriptRoot "backups"
                if (Test-Path $backupDir) {
                    Write-Host "Available backups:" -ForegroundColor Yellow
                    Get-ChildItem -Path $backupDir -Filter "*.json" | Sort-Object Name -Descending | ForEach-Object {
                        Write-Host "  $($_.FullName)" -ForegroundColor DarkGray
                    }
                }
            }
            exit 1
        }

        try {
            $dictJson = Get-Content -Path $BackupFile -Raw -Encoding utf8
            $dictData = $dictJson | ConvertFrom-Json

            # import_user_dict expects JSON body with override flag
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($dictJson)
            $uri = "{0}/import_user_dict?override={1}" -f $VoicevoxUrl, $(if ($Force) { "true" } else { "false" })
            Invoke-RestMethod -Uri $uri -Method Post -Body $bodyBytes -ContentType "application/json" -TimeoutSec 10 | Out-Null
            Write-Host "[OK] Dictionary restored from: $BackupFile" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Restore failed: $_" -ForegroundColor Red
        }
    }

    "Test" {
        if (-not $Surface) {
            Write-Host "[ERROR] -Surface is required for Test" -ForegroundColor Red
            exit 1
        }

        # 辞書でテスト文を構築
        $testText = "${Surface}の設定が完了しました。${Surface}は正常に動作しています。"
        Write-Host "Test text: $testText" -ForegroundColor Cyan

        try {
            # audio_query
            $encodedText = [uri]::EscapeDataString($testText)
            $queryUri = "{0}/audio_query?text={1}&speaker={2}" -f $VoicevoxUrl, $encodedText, $SpeakerId
            $query = Invoke-RestMethod -Uri $queryUri -Method Post -TimeoutSec 10

            # synthesis
            $queryJson = $query | ConvertTo-Json -Depth 10
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($queryJson)
            $synthUri = "{0}/synthesis?speaker={1}" -f $VoicevoxUrl, $SpeakerId
            $wavPath = Join-Path $env:TEMP "voicevox_dict_test_$([guid]::NewGuid().ToString('N').Substring(0,8)).wav"
            Invoke-WebRequest -Uri $synthUri -Method Post -Body $bodyBytes -ContentType "application/json" -OutFile $wavPath -TimeoutSec 30

            # play (using ffplay for simplicity, or SoundPlayer)
            $ffplay = Get-Command ffplay -ErrorAction SilentlyContinue
            if ($ffplay) {
                Write-Host "Playing..." -ForegroundColor Green
                Start-Process -FilePath "ffplay" -ArgumentList "-nodisp -autoexit `"$wavPath`"" -NoNewWindow -Wait
            } else {
                # Fallback: SoundPlayer
                $player = New-Object System.Media.SoundPlayer
                $player.SoundLocation = $wavPath
                Write-Host "Playing..." -ForegroundColor Green
                $player.PlaySync()
            }

            # cleanup
            Remove-Item -Path $wavPath -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Test complete" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Test failed: $_" -ForegroundColor Red
        }
    }
}
