$ErrorActionPreference = 'Stop'
$rp = 'C:\Users\minsi\AppData\Roaming\Minecraft Bedrock\Users\Shared\games\com.mojang\development_resource_packs\RetireX_Online_RP'
$ffmpeg = 'C:\Program Files\ffmpeg\bin\ffmpeg.exe'
$ffprobe = 'C:\Program Files\ffmpeg\bin\ffprobe.exe'
$outDir = $PSScriptRoot
New-Item -ItemType Directory -Force -Path (Join-Path $outDir 'source') | Out-Null
$results = @()
foreach ($name in 'cue_record','cue_middle_lap','cue_error') {
  $source = Join-Path $rp "sounds\rxoeffect\$name.ogg"
  $snapshot = Join-Path $outDir "source\$name.ogg"
  Copy-Item -LiteralPath $source -Destination $snapshot
  $m4a = Join-Path $outDir "$name.m4a"
  & $ffmpeg -hide_banner -loglevel error -y -i $snapshot -c:a aac -b:a 192k -ar 44100 -movflags +faststart $m4a
  if ($LASTEXITCODE -ne 0) { throw "변환 실패: $name" }
  & $ffmpeg -hide_banner -loglevel error -i $m4a -f null NUL
  if ($LASTEXITCODE -ne 0) { throw "디코드 실패: $name" }
  $meta = (& $ffprobe -v error -show_streams -show_format -of json $m4a | ConvertFrom-Json)
  $results += [ordered]@{ name=$name; codec=$meta.streams[0].codec_name; sampleRate=$meta.streams[0].sample_rate; channels=$meta.streams[0].channels; duration=$meta.format.duration; sourceSha256=(Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash.ToLower(); outputSha256=(Get-FileHash -LiteralPath $m4a -Algorithm SHA256).Hash.ToLower(); decodePassed=$true }
}
$json = [ordered]@{ status='2026-10-14 사용자 전 후보 승인. 원본 음량·속도·페이드 유지. 앱 청취 전.'; files=$results } | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $outDir 'validation.json'),$json+"`n",[Text.UTF8Encoding]::new($false))
$results | ForEach-Object { [pscustomobject]$_ } | Format-Table name,codec,sampleRate,channels,duration
