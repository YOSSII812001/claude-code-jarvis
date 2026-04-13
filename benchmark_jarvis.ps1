# benchmark_jarvis.ps1 - Profile each phase of JARVIS voice pipeline
$url = "http://127.0.0.1:50021"
$text = "了解しました。設定を確認します。"
$encoded = [uri]::EscapeDataString($text)
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Phase 1: audio_query
$uri = '{0}/audio_query?text={1}&speaker=21' -f $url, $encoded
$q = Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 10
$t1 = $sw.ElapsedMilliseconds
Write-Host "1. audio_query:     ${t1}ms"

# Phase 2: param + JSON serialize
$q.speedScale = 1.0; $q.pitchScale = 0.06; $q.intonationScale = 0.8; $q.volumeScale = 1.4
$q.prePhonemeLength = 0.12; $q.postPhonemeLength = 0.15
$json = $q | ConvertTo-Json -Depth 10
$body = [System.Text.Encoding]::UTF8.GetBytes($json)
$t2 = $sw.ElapsedMilliseconds
Write-Host "2. JSON serialize:  $($t2 - $t1)ms"

# Phase 3: synthesis
$wavPath = Join-Path $env:TEMP "bench_phase.wav"
Invoke-WebRequest -Uri ('{0}/synthesis?speaker=21' -f $url) -Method Post -Body $body -ContentType "application/json" -OutFile $wavPath -TimeoutSec 30
$t3 = $sw.ElapsedMilliseconds
Write-Host "3. synthesis:       $($t3 - $t2)ms"

# Phase 4: FFmpeg filter
$outPath = Join-Path $env:TEMP "bench_phase_fx.wav"
$filter = 'adelay=250|250,highpass=f=220,lowpass=f=4000,aecho=0.8:0.85:15|25|40:0.22|0.14|0.08,aphaser=in_gain=0.9:out_gain=0.9:delay=1.8:decay=0.10:speed=0.5:type=t,chorus=0.96:0.98:8|12:0.02|0.01:0.2|0.25:0.5|0.4,equalizer=f=1200:width_type=o:width=2:g=2,equalizer=f=3200:width_type=o:width=1.5:g=1.5,equalizer=f=5500:width_type=o:width=2:g=0,volume=1.6,apad=pad_dur=0.3'
$errFile = Join-Path $env:TEMP "ffbench.txt"
Start-Process -FilePath "ffmpeg" -ArgumentList "-nostdin -y -threads 1 -i `"$wavPath`" -af `"$filter`" `"$outPath`"" -NoNewWindow -Wait -RedirectStandardError $errFile
$t4 = $sw.ElapsedMilliseconds
Write-Host "4. FFmpeg filter:   $($t4 - $t3)ms"

# Phase 5: playback start
Start-Process -WindowStyle Hidden -FilePath "ffplay" -ArgumentList "-nodisp","-autoexit","-loglevel","quiet",$outPath
$t5 = $sw.ElapsedMilliseconds
Write-Host "5. playback start:  $($t5 - $t4)ms"

Write-Host ""
Write-Host "=== Total: ${t5}ms + 250ms adelay = $($t5 + 250)ms to first sound ==="
Write-Host ""
Write-Host "Bottleneck breakdown:"
$phases = @(
    @("audio_query", $t1),
    @("JSON serialize", $t2 - $t1),
    @("synthesis", $t3 - $t2),
    @("FFmpeg filter", $t4 - $t3),
    @("playback start", $t5 - $t4),
    @("adelay (fixed)", 250)
)
foreach ($p in $phases) {
    $bar = "#" * [math]::Max(1, [math]::Floor($p[1] / 30))
    Write-Host ("  {0,-16} {1,5}ms {2}" -f $p[0], $p[1], $bar)
}
