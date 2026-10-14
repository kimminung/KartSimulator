# 효과음 출처와 라이선스

## 1. 레이스 효과음 7개 — 자체 합성

| 파일 | 길이 | 출처 | 라이선스 |
| --- | --- | --- | --- |
| `countdownTick.wav` | 0.15초 | 자체 합성(`Design/tools/sfx.mjs`) | 공동 저작물(LICENSE 2조) — 외부 소재 없음 |
| `go.wav` | 0.40초 | 자체 합성 | 공동 저작물(LICENSE 2조) |
| `checkpoint.wav` | 0.30초 | 자체 합성 | 공동 저작물(LICENSE 2조) |
| `lapComplete.wav` | 0.50초 | 자체 합성 | 공동 저작물(LICENSE 2조) |
| `finish.wav` | 1.20초 | 자체 합성 | 공동 저작물(LICENSE 2조) |
| `wallBump.wav` | 0.20초 | 자체 합성 | 공동 저작물(LICENSE 2조) |
| `respawn.wav` | 0.40초 | 자체 합성 | 공동 저작물(LICENSE 2조) |

- 7개 모두 샘플·녹음·남의 소리를 쓰지 않고, 사각파(펄스)·삼각파·잡음을 코드로 합성했다. 외부 출처 표기 의무는 없다. 저작권은 루트 `LICENSE`에 따라 @kimminung·@iMasterProX 공동 소유이고, 상업적 이용·재배포는 LICENSE 4조(두 저작권자의 서면 허락)를 따른다.
- 규격: 44.1 kHz, 16비트, 모노, 피크 −12 dBFS로 정규화(디자인 PRD 10장). 고음이 날카롭지 않게 저역 통과 필터를 걸었다.
- 음 높이·길이·음색을 바꾸려면 `Design/tools/sfx.mjs`의 `SOUNDS` 표를 고치고 `node Design/tools/sfx.mjs`로 다시 만든다.

## 2. 엔진음 5개 — RetireX Online 엔진음(XK ENGINE 원본) 변환 · 운영자 확인 완료(CC0 기반)

| 파일 | 길이 | 원본(XK ENGINE `sounds/`) | RetireX에서의 이름 | 원본 SHA-256 |
| --- | --- | --- | --- | --- |
| `engineIgnition.wav` | 2.555초 | `car_on.wav` | `lemon_ignition.ogg`(RetireX는 현재 안 씀) | `9E735AAF055D89ED7E611ED257178E9DCF1676E40CF29C236581B81AB449495A` |
| `engineAccel.wav` | 2.731초 | `car_move_start.wav` | `lemon_acceleration_start.ogg` | `9F0D88FB5378F2B54B6B2ED74C8A648BC6000C91B074F4C7731EB93CA4FF8F07` |
| `engineLoop.wav` | 3.016초(루프) | `car_move_going.wav` | `lemon_engine_going.ogg` / `lemon_engine_loop.ogg` | `51B894229D7E0B74C2A5B0A87A0A0092155D1CB6000803F8F1EA5AF09F30CE75` |
| `engineDecel.wav` | 2.539초 | `car_move_end.wav` | `lemon_deceleration.ogg` | `CBC58D6A4EE9B55E14ED0571A52B921DDE838485EF2FA60FB3DA87AC903D6A25` |
| `engineIdle.wav` | 0.826초(루프) | `car_engine_waiting.wav` | (RetireX 초기 루프, 지금은 안 씀) | `BB647E966B1BC07F92ED32A6066E6DB52D04D0706B67B10C6105413814D2AB52` |

**출처 사슬**

1. 원 소유: **CYBOX DIGITAL ENTERTAINMENT**의 애드온 "XK ENGINE – Vehicle Operation System" 3.0.0이다. 운영자 PC의 `development_resource_packs/LemonONE_RP`에 있다. CYBOX는 RetireX Online을 운영하는 회사이자 이 앱 디자이너의 회사다.
2. RetireX Online은 이 원본 WAV를 OGG로 그대로 바꿔(`lemon_*.ogg`) 쓴다. 근거는 RetireX의 `LEMONONE_ASSET_PROVENANCE.md`(2026-08-01 감사)다. 위 SHA-256은 그 기록의 원본 값과 같고, 변환 도구가 실행할 때마다 다시 확인한다.
3. 이 앱의 파일은 RetireX의 OGG가 아니라 손실 없는 원본 WAV에서 만들었다(`node Design/tools/engine.mjs`). 처리는 다음과 같다.
   - 스테레오를 모노로 합쳤다.
   - 5개 공통 이득 −11.7 dB를 걸어, 가장 큰 피크(`engineLoop`)가 −12 dBFS가 되게 했다.
   - 단발 소리는 끝에 짧은 페이드를 넣었다.
   - `engineLoop`·`engineIdle`은 이음매 없는 루프로 잘랐다. 자르는 지점은 `Assets/sfx/ENGINE.md` 1장에 있다.

**라이선스 확인 (2026-10-11, 운영자)**

- 운영자(CYBOX, 디자이너) 확인: 엔진음 5개의 녹음 원본은 **별도 라이선스가 없는 CC0 파일**을 바탕으로 만든 것이다. 출처 표기·재배포 제약이 없으므로 공개 레포 커밋과 앱 출시에 문제없다.
- 따라서 `Assets/sfx/engine*.wav`와 미리듣기 `Design/audio/engine_preview.wav`를 커밋한다. 아래 3장 합성 대체본은 예비로 함께 둔다.

## 3. 엔진음 합성 대체본 — 자체 합성

`node Design/tools/engine.mjs --synth`가 같은 이름의 파일 5개를 `Design/audio/engine_synth/`에 만든다. 단기통 엔진의 점화 펄스, 낮은 잡음, 두 단 저역 통과로 만든 소리이고, 외부 소재가 없어 루트 `LICENSE` 2조의 공동 저작물이다. 2장 원본을 쓸 수 없게 되면 이 5개를 `Assets/sfx/`로 복사한다. 파일명과 루프 여부가 같고 단발 소리 길이도 0.01초 안쪽으로 같아서, 코드는 바꿀 필요가 없다(루프 길이는 달라도 상관없다).

## 4. 공통

- 마인크래프트(Mojang) 소리는 쓰지 않는다(결정 21). RetireX Online이 쓰는 바닐라 소리(워프 등)도 가져오지 않았다.
- 나중에 외부 CC0 소리(Kenney, freesound CC0 등)로 바꾸면 이 표에 출처 URL과 라이선스를 적는다.

## 5. 카운트다운·출발음 신규 전달본 — 사용자 지정 리소스

2026-10-14 사용자 지정 개발 RP `RetireX_Online_RP/sounds/rxoeffect/`의 stttt.ogg·start.ogg를 AAC M4A로 변환했다. `Assets/sfx/countdown/`에 원본·변환본·재생 간격·검증 결과를 함께 보관한다.

| 원본 | 전달본 | 원본 SHA-256 |
| --- | --- | --- |
| stttt.ogg | countdown/stttt.m4a | `BFBDB3E98BC144F96B158DFE914BA4479D9B37A3CF012BDDC90EE17DA9BA61CA` |
| start.ogg | countdown/start.m4a | `9F548F2BCF5F3EE40C29F3D0E07F65C0B94AFFC4836C44C7EB97922C7688AC7F` |

포맷만 변환했으며 원본의 음량·페이드·재생 속도는 유지했다. 사용자 지정 소리 사용 요청과 2026-10-14 공유 준비 요청에 따라 로컬 커밋 대상으로 확정했다. 원격 게시 전이다. 2장의 엔진음 CC0 확인을 이 두 파일이나 추가 효과음 후보의 원출처 확인으로 대신하지 않는다. 실제 앱 연결·청취는 테크 인계의 후속 항목이다.

## 6. 기록·랩·오류 소리 — 사용자 전 후보 승인

2026-10-14 사용자 지정 RetireX_Online_RP/sounds/rxoeffect/의 cue_record.ogg·cue_middle_lap.ogg·cue_error.ogg를 Assets/sfx/ui-cues/에 원본과 AAC M4A로 준비했다. 사용자 추가 후보 전체 승인에 따른다. 변환 시 원본 음량·속도·채널 수를 유지했다.

| 원본 | 원본 SHA-256 |
| --- | --- |
| cue_record.ogg | `144821f477a9b6c0dc0d140db99016827c9b910983c81ab4c89f5bd1a7529c8c` |
| cue_middle_lap.ogg | `c3bec14df04236707fa15fecce4ebe89f45f9b95761b3ef00e61a9bdcb9c7420` |
| cue_error.ogg | `0349ae4664b56643c6dd1be9424aefbd2932714874d615bba686f79e24fe85c5` |

사용자 승인과 출처 사본·해시 기록을 보존한다. 기존 엔진음의 CC0 기록을 신규 음원에 확대 적용하지 않는다. 앱 이벤트 연결·실기기 청취는 후속이다.
