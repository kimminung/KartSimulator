# RetireX 카운트다운·출발 효과음 전달본

2026-10-14 · 사용자 요청 · 결정 63 · 사용자 승인·공유 준비 완료

사용자가 지정한 로컬 개발 RP의 `sounds/rxoeffect/stttt.ogg`·`start.ogg`를 AAC M4A로 변환했다. 원본 OGG는 `source/`에 바이트 동일하게 보관한다. 기존 합성 `countdownTick.wav`·`go.wav`는 그대로이며 앱 적용 때 아래 M4A로 연결한다.

| 파일 | 형식 | 길이 | 원본 |
| --- | --- | --- | --- |
| `stttt.m4a` | AAC 192 kbps, 44.1 kHz 스테레오 | 약 2.997초 | `stttt.ogg` |
| `start.m4a` | AAC 192 kbps, 44.1 kHz 스테레오 | 약 3.740초 | `start.ogg` |

음량 정규화·트림·페이드·피치 변경 없이 포맷만 변환했다. 기존 엔진음의 CC0 확인 기록을 이 두 효과음에 자동 적용하지 않는다. 출처는 사용자 지정 RP이며 공개 커밋 전 사용자 검토를 받는다.

## 재생 규칙 — 사용자 최신 요청 반영

준비 신호와 숫자의 간격을 **3.1초**로 늘린다. 약 2.997초인 원본 준비음의 꼬리까지 끝난 후 다음 숫자와 준비음을 시작한다. 각 숫자에서 준비음은 한 번씩, 합계 세 번 재생한다. 음원을 자르거나 재생 속도를 늦추지 않는다.

| 시점 | 표시 | 재생 |
| --- | --- | --- |
| t=0초 | 3 | `stttt.m4a` 새 인스턴스 |
| t=3.1초 | 2 | 앞 준비음이 끝난 뒤 `stttt.m4a` |
| t=6.2초 | 1 | 앞 준비음이 끝난 뒤 `stttt.m4a` |
| t=9.3초 | GO! | 마지막 준비음이 끝난 뒤 `start.m4a` |

간격과 준비음 길이의 차이는 약 0.103초다. 같은 플레이어를 1초마다 되감아 음원 꼬리를 끊거나, 이전 준비음과 겹쳐 재생하지 않는다. 레이스 종료·닫기·카운트다운 취소·다시 시작 시에는 이전 카운트다운의 인스턴스를 정리한다. 재개 카운트다운도 같은 3.1초 간격·3회 규칙을 쓴다.

기존 visionOS·iOS의 `[3,2,1]` 루프에서 각 1초 대기를 공용 3.1초 값으로 바꾼다. 테크가 `SFXPlayer`의 `.countdownTick`을 `stttt.m4a`, `.go`를 `start.m4a`에 연결한다. 약 9.3초 동안 주행 입력과 랩 타이머는 잠금 상태를 유지하고, GO에서 주행·BGM을 시작한다. 엔진 시동·아이들 전환과 재개 흐름도 길어진 카운트다운에 맞게 확인한다.

## 미리듣기와 검증

`preview_3_2_1_go.m4a`는 0·3.1·6.2초에 준비음을 놓고 9.3초에 출발음을 놓은 약 13.041초 재생 예시다. 미리듣기 합성본에만 전체 이득 0.5(약 −6 dB)를 적용했다. 전달용 개별 M4A의 원본 음량은 그대로다.

FFprobe로 AAC·44.1 kHz·스테레오·길이를 확인했고, FFmpeg 디코드와 준비음 길이가 3.1초 간격보다 짧음을 확인했다. 설정과 수치는 `countdown_spec.json`·`validation.json`에 있다. 실제 앱의 표시·재생 동기화와 실기기 청취는 테크·사용자 후속 확인이다.

## 재변환

개별 음원 변환·간격에 맞춘 미리듣기·검증을 함께 다시 만들려면 `build.ps1`을 실행한다.

```powershell
& Assets/sfx/countdown/build.ps1
```

```powershell
ffmpeg -i source/stttt.ogg -map_metadata -1 -c:a aac -b:a 192k -ar 44100 -ac 2 -movflags +faststart stttt.m4a
ffmpeg -i source/start.ogg -map_metadata -1 -c:a aac -b:a 192k -ar 44100 -ac 2 -movflags +faststart start.m4a
```

원본 SHA-256:

- stttt: `BFBDB3E98BC144F96B158DFE914BA4479D9B37A3CF012BDDC90EE17DA9BA61CA`
- start: `9F548F2BCF5F3EE40C29F3D0E07F65C0B94AFFC4836C44C7EB97922C7688AC7F`
