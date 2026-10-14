$ErrorActionPreference = 'Stop'
$audioRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$audioFfmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (!$audioFfmpeg) { $audioFfmpeg = 'C:\Program Files\ffmpeg\bin\ffmpeg.exe' }
$audioFfprobe = Join-Path (Split-Path -Parent $audioFfmpeg) 'ffprobe.exe'
$audioSpec = Get-Content -LiteralPath (Join-Path $audioRoot 'countdown_spec.json') -Raw | ConvertFrom-Json
$audioValidation = @()
foreach ($audioName in @('stttt','start')) {
    $audioInput = Join-Path $audioRoot "source\$audioName.ogg"
    $audioOutput = Join-Path $audioRoot "$audioName.m4a"
    & $audioFfmpeg -hide_banner -loglevel error -nostdin -y -i $audioInput -map_metadata -1 -c:a aac -b:a 192k -ar 44100 -ac 2 -movflags +faststart $audioOutput
    if ($LASTEXITCODE -ne 0) { throw "$audioName 변환 실패" }
    & $audioFfmpeg -hide_banner -loglevel error -nostdin -i $audioOutput -f null NUL
    if ($LASTEXITCODE -ne 0) { throw "$audioName 디코드 실패" }
    $audioProbe = (& $audioFfprobe -v error -show_entries format=duration:stream=codec_name,sample_rate,channels -of json $audioOutput | ConvertFrom-Json)
    if ($audioProbe.streams[0].codec_name -ne 'aac' -or $audioProbe.streams[0].sample_rate -ne '44100' -or $audioProbe.streams[0].channels -ne 2) { throw "$audioName 출력 형식 불일치" }
    $audioValidation += [pscustomobject]@{file="$audioName.m4a";duration=[double]$audioProbe.format.duration;codec=$audioProbe.streams[0].codec_name;rate=$audioProbe.streams[0].sample_rate;channels=$audioProbe.streams[0].channels;sourceSha256=(Get-FileHash -LiteralPath $audioInput -Algorithm SHA256).Hash;outputSha256=(Get-FileHash -LiteralPath $audioOutput -Algorithm SHA256).Hash}
}
$audioCountdownDuration = $audioValidation[0].duration
if ($audioCountdownDuration -ge $audioSpec.countdownStepSeconds) { throw '준비음이 간격보다 길어 중첩됩니다.' }
$audioDelay2 = [int][Math]::Round($audioSpec.events[1].timeSeconds * 1000)
$audioDelay1 = [int][Math]::Round($audioSpec.events[2].timeSeconds * 1000)
$audioDelayGo = [int][Math]::Round($audioSpec.events[3].timeSeconds * 1000)
$audioFilter = "[0:a]asplit=3[s3][s2][s1];[s2]adelay=$audioDelay2|$audioDelay2[d2];[s1]adelay=$audioDelay1|$audioDelay1[d1];[1:a]adelay=$audioDelayGo|$audioDelayGo[go];[s3][d2][d1][go]amix=inputs=4:duration=longest:normalize=0,volume=0.5[preview]"
$audioPreview = Join-Path $audioRoot 'preview_3_2_1_go.m4a'
& $audioFfmpeg -hide_banner -loglevel error -nostdin -y -i (Join-Path $audioRoot 'stttt.m4a') -i (Join-Path $audioRoot 'start.m4a') -filter_complex $audioFilter -map '[preview]' -c:a aac -b:a 192k -movflags +faststart $audioPreview
if ($LASTEXITCODE -ne 0) { throw '카운트다운 예시 합성 실패' }
$audioPreviewProbe = (& $audioFfprobe -v error -show_entries format=duration -of json $audioPreview | ConvertFrom-Json)
$audioReport = [pscustomobject]@{files=$audioValidation;countdownStepSeconds=$audioSpec.countdownStepSeconds;goTimeSeconds=$audioSpec.events[3].timeSeconds;overlap=$false;gapSeconds=$audioSpec.countdownStepSeconds-$audioCountdownDuration;previewDuration=[double]$audioPreviewProbe.format.duration;previewGain=$audioSpec.previewGain;appDevicePlaybackVerified=$false}
[System.IO.File]::WriteAllText((Join-Path $audioRoot 'validation.json'),($audioReport | ConvertTo-Json -Depth 8)+"`n",[System.Text.UTF8Encoding]::new($false))
$audioReport | ConvertTo-Json -Depth 8
