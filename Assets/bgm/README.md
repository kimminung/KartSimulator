# 배경음 (결정 55)

레이스 중에 까는 배경음 3곡입니다. 디자이너가 요청하고 테크가 승인했습니다(2026-10-12). 앱에는 `.m4a`를 넣습니다.

| 파일 | 곡 | 길이 | 음량 |
| --- | --- | --- | --- |
| `escape_with_break.m4a` | Race Music - Escape With Break | 162.4초 | −20.1 LUFS, 피크 −9.6 dBFS |
| `neon_speed_run.m4a` | Race Music - Neon Speed Run | 269.3초 | −20.0 LUFS, 피크 −5.1 dBFS |
| `neon_velocity.m4a` | Race Music - Neon Velocity | 149.6초 | −20.1 LUFS, 피크 −7.6 dBFS |

## 출처와 라이선스

- 원곡: iMasterProX, 앨범 "RetireX Online Soundtrack". 원본은 `source/*.ogg`(Ogg Vorbis, 48 kHz 스테레오)이고, 태그에 제목·아티스트·앨범이 들어 있습니다.
- 라이선스: 이 레포의 루트 `LICENSE`를 따릅니다(2조 공동 저작물, @kimminung·@iMasterProX). 외부 소재가 없습니다.

## 변환

Apple 플랫폼은 Ogg Vorbis를 기본으로 재생하지 못해서 AAC로 바꿨습니다. 원곡의 통합 음량은 −15~−16 LUFS로, 효과음(피크 −12 dBFS)·엔진음 위로 올라옵니다. 그래서 곡마다 **일정한 이득**만 걸어 −20 LUFS로 맞췄습니다. 압축이나 리미터를 쓰지 않아 다이내믹은 원곡 그대로입니다.

```bash
ffmpeg -i source/<곡>.ogg -af "volume=<−20 − 원곡 LUFS>dB" -c:a aac -b:a 192k -ar 48000 -ac 2 -map_metadata 0 -movflags +faststart <곡>.m4a
```

| 곡 | 원곡 통합 음량 | 이득 |
| --- | --- | --- |
| escape_with_break | −16.1 LUFS | −3.9 dB |
| neon_speed_run | −15.1 LUFS | −4.9 dB |
| neon_velocity | −15.7 LUFS | −4.3 dB |

음량은 `ffmpeg -i <파일> -af ebur128=peak=true -f null -`로 확인합니다.

## 재생 규칙 (제안 — 테크와 확정)

| 순간 | 배경음 |
| --- | --- |
| 메뉴, 출발 대기, 카운트다운 | 재생 안 함 |
| "GO" | 곡 처음부터 1.0초 페이드 인 |
| 레이스 중 | 한 곡 반복 재생(파일 전체가 한 바퀴) |
| 일시정지 | −10 dB로 0.3초 동안 내림, 재개 시 원래대로 |
| 리스폰 | 그대로 |
| 완주 | 2.0초 페이드 아웃. 결과 화면은 조용히 |
| 트랙 선택·종료 | 0.5초 페이드 아웃 후 정지 |

- **곡 배정**: 트랙마다 한 곡을 고정하거나, 레이스마다 세 곡을 순서대로 돌립니다. 테크가 정합니다.
- **음량 배치**: 배경음 버스 −6 dB, 엔진 버스 −6 dB(`Assets/sfx/ENGINE.md` 3-5), 효과음 0 dB. 효과음이 가장 또렷하게 들려야 합니다.
- **공간 음향 아님**: 카트에 붙이지 않고 머리 고정(앰비언트)으로 재생합니다. 3인칭에서 세계가 돌아도 음악은 돌지 않아야 합니다.
- 맞는지 실기기에서 들어 보고, 엔진음이 묻히면 배경음 버스를 −9 dB로 내립니다.
