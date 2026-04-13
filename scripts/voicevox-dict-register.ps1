# VOICEVOX User Dictionary Batch Registration Script
# Usage: pwsh -File voicevox-dict-register.ps1

$baseUrl = "http://localhost:50021"
$words = @(
    # Development Tools & Services
    @{ surface = "Lint"; pronunciation = "リント" }
    @{ surface = "CodeRabbit"; pronunciation = "コードラビット" }
    @{ surface = "Codex"; pronunciation = "コーデックス" }
    @{ surface = "Playwright"; pronunciation = "プレイライト" }
    @{ surface = "Supabase"; pronunciation = "スーパーベース" }
    @{ surface = "Vercel"; pronunciation = "バーセル" }
    @{ surface = "Stripe"; pronunciation = "ストライプ" }
    @{ surface = "GitHub"; pronunciation = "ギットハブ" }
    @{ surface = "Docker"; pronunciation = "ドッカー" }
    @{ surface = "Vite"; pronunciation = "ヴィート" }
    @{ surface = "Turbopack"; pronunciation = "ターボパック" }
    @{ surface = "Turborepo"; pronunciation = "ターボレポ" }
    @{ surface = "ESLint"; pronunciation = "イーエスリント" }
    @{ surface = "TypeScript"; pronunciation = "タイプスクリプト" }
    @{ surface = "webpack"; pronunciation = "ウェブパック" }
    # Frameworks & Libraries
    @{ surface = "React"; pronunciation = "リアクト" }
    @{ surface = "Next.js"; pronunciation = "ネクストジェイエス" }
    @{ surface = "Vue"; pronunciation = "ビュー" }
    @{ surface = "Svelte"; pronunciation = "スベルト" }
    @{ surface = "Express"; pronunciation = "エクスプレス" }
    @{ surface = "Prisma"; pronunciation = "プリズマ" }
    @{ surface = "shadcn"; pronunciation = "シャドシーエヌ" }
    @{ surface = "Tailwind"; pronunciation = "テイルウィンド" }
    @{ surface = "Material-UI"; pronunciation = "マテリアルユーアイ" }
    @{ surface = "Radix"; pronunciation = "ラディックス" }
    # AI & Cloud
    @{ surface = "Claude"; pronunciation = "クロード" }
    @{ surface = "Anthropic"; pronunciation = "アンスロピック" }
    @{ surface = "OpenAI"; pronunciation = "オープンエーアイ" }
    @{ surface = "GPT"; pronunciation = "ジーピーティー" }
    @{ surface = "LLM"; pronunciation = "エルエルエム" }
    @{ surface = "Gemini"; pronunciation = "ジェミニ" }
    @{ surface = "gBizINFO"; pronunciation = "ジービズインフォ" }
    # Git & CI/CD
    @{ surface = "squash"; pronunciation = "スカッシュ" }
    @{ surface = "rebase"; pronunciation = "リベース" }
    @{ surface = "merge"; pronunciation = "マージ" }
    @{ surface = "commit"; pronunciation = "コミット" }
    @{ surface = "staging"; pronunciation = "ステージング" }
    @{ surface = "deploy"; pronunciation = "デプロイ" }
    @{ surface = "Pull Request"; pronunciation = "プルリクエスト" }
    # Project-specific
    @{ surface = "Usacon"; pronunciation = "ウサコン" }
    @{ surface = "Robbits"; pronunciation = "ロビッツ" }
    @{ surface = "auto-fill"; pronunciation = "オートフィル" }
    @{ surface = "DX"; pronunciation = "ディーエックス" }
    @{ surface = "IoT"; pronunciation = "アイオーティー" }
    @{ surface = "CSF"; pronunciation = "シーエスエフ" }
    @{ surface = "SSE"; pronunciation = "エスエスイー" }
    @{ surface = "webhook"; pronunciation = "ウェブフック" }
    @{ surface = "CRUD"; pronunciation = "クラッド" }
    @{ surface = "API"; pronunciation = "エーピーアイ" }
    @{ surface = "SDK"; pronunciation = "エスディーケー" }
    @{ surface = "MCP"; pronunciation = "エムシーピー" }
    @{ surface = "UUID"; pronunciation = "ユーユーアイディー" }
    @{ surface = "JARVIS"; pronunciation = "ジャービス" }
    @{ surface = "cheerio"; pronunciation = "チェリオ" }
    @{ surface = "axios"; pronunciation = "アクシオス" }
)

# Check VOICEVOX is running
try {
    $null = Invoke-RestMethod -Uri "$baseUrl/user_dict" -Method Get -TimeoutSec 3
} catch {
    Write-Host "ERROR: VOICEVOX is not running at $baseUrl" -ForegroundColor Red
    exit 1
}

# Get existing dictionary
$existing = Invoke-RestMethod -Uri "$baseUrl/user_dict" -Method Get
$existingSurfaces = @()
foreach ($key in $existing.PSObject.Properties.Name) {
    $existingSurfaces += $existing.$key.surface
}
Write-Host "Existing entries: $($existingSurfaces.Count)" -ForegroundColor Cyan

$added = 0
$skipped = 0
$failed = 0

foreach ($word in $words) {
    if ($existingSurfaces -contains $word.surface) {
        Write-Host "  SKIP: $($word.surface) (already exists)" -ForegroundColor Yellow
        $skipped++
        continue
    }
    try {
        $uri = "$baseUrl/user_dict_word?surface=$([Uri]::EscapeDataString($word.surface))&pronunciation=$([Uri]::EscapeDataString($word.pronunciation))&accent_type=0&word_type=PROPER_NOUN&priority=5"
        $null = Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 5
        Write-Host "  OK: $($word.surface) -> $($word.pronunciation)" -ForegroundColor Green
        $added++
    } catch {
        Write-Host "  FAIL: $($word.surface) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n=== Results ===" -ForegroundColor Cyan
Write-Host "Added: $added / Skipped: $skipped / Failed: $failed / Total: $($words.Count)" -ForegroundColor Cyan
