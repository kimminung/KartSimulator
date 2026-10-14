# 핀치 로버(옛 가칭 핀치 카트) — 태스크 문서

Oct 10, 2026 · @Coulson 기준, `Docs/tech-prd.md`에서 파생. 마일스톤 순서대로 진행하고, 완료한 항목은 체크하며 날짜를 적는다. 결정이 바뀌면 `Docs/decisions.md`에 먼저 기록한다.

## 아키텍처 업데이트 (테크 PRD 대비 변경점)

테크 PRD 1장의 "기본 제안"에서 아래 3가지가 바뀌었다. 상세 이유는 `Docs/decisions.md` 참고.

1. **공간 구성**: Volumetric `WindowGroup` 대신 `ImmersiveSpace` + `.immersionStyle(selection:in: .progressive)`를 쓴다. 콘텐츠는 박스 모양 프레임(와이어프레임 엣지 + 바닥판)으로 경계를 표시한 디오라마이며, 사용자는 Digital Crown을 돌려 몰입도(이머시브 공간 ↔ 바깥 패스스루)를 조절한다.
2. **카트 에셋**: Blockbench 단일 모델(`kart_01`) 파이프라인 대신, 완성형 USDZ 5종(`arcrix`, `bogubkart`, `gospel`, `razr`, `sirius`)을 최종 로스터로 쓴다(`mms`는 카트가 아닌 일반 자동차 모델이라 제외, 결정 34번). 5종 모두 색상 17종(`red`/`orange`/`yellow`/`lime`/`green`/`cyan`/`light_blue`/`blue`/`purple`/`magenta`/`pink`/`brown`/`black`/`gray`/`silver`/`white`/`undyed`, 색상환 순) 텍스처 변형을 갖고 있다.
3. **`KartCore` 위치**: 별도 Swift 패키지(SPM) 대신, `KartSimulator` 앱 타깃 안의 `KartCore/` 폴더에 플랫폼 독립 로직(RealityKit·SwiftUI 미의존)으로 둔다. 단위 테스트는 호스트형 `KartCoreTests` 타깃(Swift Testing)에서 `@testable import KartSimulator`로 검증한다.

## M0 — 프로젝트 셋업

- [x] visionOS 플랫폼 빌드 확인 (타깃은 이미 `xros`/`xrsimulator` 포함한 멀티플랫폼)
- [x] 카트 USDZ 6종을 프로젝트에 추가 (`KartSimulator/Resources/Karts/`)
- [x] `KartCoreTests` 유닛 테스트 타깃 추가 (Swift Testing, 호스트 앱 KartSimulator)
- [ ] `RealityKitContent` 패키지 분리 — 커스텀 컴포넌트가 생기는 M3부터 필요

## M1 — 박스 이머시브 공간 + 카트 쇼케이스

- [x] `ImmersiveSpace` + 박스 프레임(와이어프레임) + 바닥판 다이오라마 구현
- [x] 메뉴 윈도우에 카트 6종 선택 그리드 + 색상 스와치(해당 카트만) 추가
- [x] 선택한 카트를 박스 안에 로드, 바운딩 박스 기준 자동 스케일·중앙 정렬
- [x] 색상 선택 시 베이스컬러/이미시브 텍스처 교체
- [ ] 실기기에서 Digital Crown으로 몰입도 조절 확인 (시뮬레이터는 크라운 입력 제한적 — 체크리스트에 남김)
- [x] 카트 회전/관찰용 간단한 제스처(드래그로 회전) 추가 — 메뉴 `KartCard`에 구현 (결정 34번)
- [x] 카트 카드 기본은 정적 썸네일, 호버/포커스 시에만 1.4배로 커지며 라이브 3D+드래그 회전으로 전환 (결정 36-2, 37번) — 카드 5장이 전부 라이브면 산만하다는 디자인 피드백 반영

## M2 — 입력 프로토타입 (2026-10-10 1차 구현 완료)

- [x] `KartCore/DriveState.swift`, `InputTuning.swift`, `MotionTuning.swift` — 테크 PRD 5·6장 수치 그대로 이식
- [x] `HandInputResolver`: 핀치 디바운스(40ms)·해제 그레이스(120ms)·손 추적 끊김(300ms)·손 거리 EMA 스무딩(α=0.25)·스프레드 히스테리시스까지 반영해 `DriveState` 6종 판정
- [x] `KartMotionState.advancing(drive:tuning:deltaTime:)`: 가속/브레이크/코스트 감속, 속도 기반 회전율 보간, 전진 적분 (테크 PRD 6장 의사코드 그대로)
- [x] 단위 테스트 13개 작성·통과 (`KartCoreTests`): 상태 판정 6케이스, 디바운스/그레이스/스테일, 히스테리시스, 모션 적분 1초, 회전 중 속도 유지
- [x] `ImmersiveBoxView`에 연결: `SpatialEventGesture`로 양손 핀치 수신 → `HandInputResolver` → 매 프레임(`SceneEvents.Update`) `KartMotionState`로 박스 바닥 안에서 카트 주행, 벽(박스 경계)에 닿으면 방향 반사
  - 트랙 타일이 아직 없어 박스 바닥 전체를 임시 주행장으로 씀. 실제 트랙 좌표계/이탈 판정은 M3에서 교체
  - 모션 튜닝 값은 작은 박스 크기에 맞춰 축소한 임시값(`maxSpeed 0.3` 등). 실제 트랙 스케일 값(PRD 6장 기본값)은 M3에서 복원
- [ ] 실기기 테스트: 손 구분 10/10, 벌림 0.22m/0.40m 경계 안정성 (테크 PRD 12장 체크리스트) — 시뮬레이터에서는 손 추적 입력이 제한적이라 보류
- [ ] 게이트 실패 시 ARKit `HandTrackingProvider` 전환 여부 결정 (테크 PRD 1장 (c))
- [x] **운전 모드 3종(디오라마·1인칭·3인칭) Phase 1** (결정 39번) — `ExperienceMode` 추가, `HandInputResolver.resolve(now:mode:)`로 모드별 해석 분리(디오라마: 핀치 시작 지점 대비 상대 드래그로 전·후진+한손 회전, 3인칭: 같은 손 모양이지만 후진 없음, 1인칭: 한손 이상 핀치=가속+머리 방향 조향), `KartMotionState.advancing(drive:desiredHeading:tuning:deltaTime:)`에 머리 방향 추종 조향 추가. `ImmersiveBoxView`에 모드 전환 버튼(`ModeSwitchView`, 시스템 표준 시선+핀치 선택) 추가
- [x] **Phase 2**: 1인칭/3인칭 트랙을 실제 크기로 렌더링 + 유저 머리 위치에 카트를 맞추는 콕핏 기법 (결정 44~46, 2026-10-11 실기기 확인 완료). 스트리밍/컬링은 프레임 저하 보고가 없어 보류 유지
- [x] 실기기 확인(2026-10-11): 디오라마 전후진(상대 드래그) 자연스러움, 1인칭 조향감 120°/s 적절 — 시연 영상 README 참고

## Phase 2 — 1인칭·3인칭 콕핏 (2026-10-11 구현, 결정 44)

- [x] 트랙·카트·트레일을 `sceneRoot`(트랙 좌표계 실제 크기) 아래로 옮기고 모드별로 씬 루트 변환만 바꾸기 — 디오라마는 기존 배율·180° 회전, 콕핏은 배율 1
- [x] 콕핏 따라붙기(`followKart`): 매 프레임 카트 트랙 좌표 → 머리 기준 목표점(1인칭 아래 0.9 m / 3인칭 앞 2.5 m·아래 1.8 m), 월드는 평행이동만
- [x] 모드 전환 시 박스 숨김, HUD 머리 앞 고정, 입력 캐처 40 m, 카트 실제 크기(1.5 m) 재맞춤, 출발 방향 = 머리 방향
- [x] `ScenePlacement`/`CockpitTuning` + `ScenePlacementTests` 6개
- [x] 실기기 1차 확인(2026-10-11): 디오라마 동일, 1인칭 실제 크기·발밑·머리 조향, 3인칭 앞·아래, 콕핏 핀치·HUD 모두 OK. 프레임 저하 보고 없음(컬링 보류 유지)
- [x] 3인칭 멀미 피드백 → 카트를 바라보는 방향 앞에 두고 머리 yaw 평활(결정 45)
- [x] 실기기 2차(2026-10-11): 3인칭 중앙 고정 OK, 멀미 감소 OK (결정 45, PR #20)
- [x] 3인칭 추적 카메라: 씬 yaw를 "카트 뒤에서 앞" 목표로 2.5/s 평활 회전(결정 46)
- [x] 실기기 3차(2026-10-11): 추적 카메라 만족, 회전 2.5/s 멀미 없음 (PR #21 머지)
- [ ] 보류: 콕핏 내부 모델(핸들·대시보드), 사용자가 걸어 다닐 때 anchor 갱신, 디버그 전용 코드(헤드 기즈모·트레일·DEBUG 로그) 정리

## 리뷰 회의 반영 (2026-10-11, 결정 47 → 48·49)

- [x] Issue #24 1인칭 폐기, 조작 통일(3인칭 = 디오라마 규칙, 후진 포함) — 결정 49
- [x] Issue #25 3인칭 카메라 기준 = 진입 순간 머리 yaw 고정, ±45° 자유, 60°·2초 리센터(1.0/s) — `ChaseCameraReference`
- [x] Issue #23 ①정면 마커 정확 일치 ②카트 높이 노면 윗면 0.25 m — 결정 49
- [ ] Issue #23 ③바퀴 바닥 접지, Issue #26 바퀴 굴림·조향·핸들·기울기 — **USDZ에 바퀴 그룹 이름(A~D)이 없음**. 바퀴 이름이 보존된 재내보내기 필요(디자인에 요청)
- [x] Issue #31 `EngineSoundMachineTests` 5개 수정(시동 2.2초 부동소수점, 빠를 때 가속→루프 조기 전환)
- [x] Issue #27 창 배치: 박스 (0, 0.85, −0.9)로 내림 + 3인칭에서 메뉴 창 dismiss/종료 시 openWindow — 결정 51
- [x] Issue #26 일부: 핸들 82° 핀치 연동·차체 roll/pitch(`KartRigPose`/`KartRig`), 바퀴 코드는 재내보내기 대기 — 결정 51
- [ ] #28 속도계(리소스 대기, 눈금 0~20 km/h 제안), #29 운전자(에셋 대기), #30 앱 이름 확정됨(결정 53), #31 나머지는 디자인 소유 문서 + mms 히스토리 결정
- [ ] 실기기: razr 정면, 5종 노면 위, 3인칭 고개 자유·리센터, 3인칭 후진 체감

## M3 — 트랙 + 주행 로직 (2026-10-10 트랙 생성·검증 스크립트 완료)

- [x] 트랙 타일 4종 에셋 확보 + 배치 — `Assets/export/glb/tile_*.glb`(디자인 전달, 결정 36-4)를 헤드리스 Blender(`wm.usd_export`, Y-up/-Z-forward 변환)로 `.usdz` 변환해 `KartSimulator/Resources/Tiles/`에 넣고, `TrackTileLibrary` + `ImmersiveBoxView.buildTrackTiles(definition:into:)`로 그리드 전체(타일 바운딩 사각형 + 빈 칸은 `grass`)를 실제 3D로 깐다. 점열 placeholder(`buildTrackVisual`)는 제거.
- [x] `Tracks/tools/gen_track.py`, `validate_track.py` 작성
  - 그리드 중앙 사각 루프 + "노치"(변 일부를 바깥으로 밀어내는 삽입)로 난이도별 복잡도 조절
  - 검증 5종 모두 구현: 단일 순환/연결 변 일치, path 닫힘·자기교차 없음, 출발선 위치, 체크포인트 개수·순서, 한 바퀴 길이 60~140m
  - easy/normal/hard × seed 1~8, 8×6 그리드로 24개 생성·검증 전부 통과
  - `Tracks/track_01.json`(seed 20261010, easy, 타일 16/64점), `Tracks/track_02.json`(seed 20261011, normal, 타일 18/72점) 커밋 — 아직 타일 3D 에셋이 없어 데이터만 존재, 렌더링은 타일 에셋 확보 후
  - **알게 된 점**: 노치 1개는 새 코너 2개뿐 아니라 노치 양옆의 기존 직선 타일 2개도 커브로 바꿔 커브 +4가 된다(+2 아님). 그래서 난이도는 "목표 커브 수"가 아니라 "노치 개수"로 조절한다(easy=0/4커브, normal=1/8커브, hard=2/12커브) — PRD의 "normal 6개"는 이 구조에서 나올 수 없어 8로 대체했다(`Docs/decisions.md` 17번)
- [x] 박스 임시 주행장(M2) → 실제 트랙 좌표계·타일 배치로 교체
  - `KartCore/TrackDefinition.swift`: `Tracks/track_XX.json` 스키마 그대로 Codable로 디코딩, `MotionTuning.applying(_:)`로 JSON `tuning` 일부 덮어쓰기 지원
  - `KartCore/TrackPath.swift`: 중심선(`path`)에 대한 최근접 구간/수직 거리 계산 (이탈 판정·path 인덱스 추적에 사용)
  - `KartCore/LapTracker.swift`: 체크포인트를 순서대로 "전진 방향"으로 지났는지, 출발선을 다시 지났는지 판정. 역주행·리스폰 점프는 크로스로 안 침 (테크 PRD 12장 체크리스트 항목)
  - `KartCore/OffTrackMonitor.swift`: 트랙 밖 체류 시간 누적 → `offTrackRespawn` 초과 시 리스폰 신호
  - 단위 테스트 10개 추가(`KartCoreTests`), 총 23개 전부 통과
  - `ImmersiveBoxView`: `track_01.json`(앱 번들에 복사된 사본, `KartSimulator/Resources/Tracks/`)을 읽어 트랙 전체 바운딩 박스를 박스 바닥에 자동으로 맞추는 배율(`trackDisplayScale`)을 계산 → 같은 배율로 카트도 스케일(`KartFitter.fit(_:scale:)` 추가)해 비례를 맞춤 → path를 작은 점열로 시각화(타일 3D 에셋 없음, 임시) → 실제 PRD 모션 수치로 주행, 센터라인 이탈 2초 후 출발선 리스폰, 체크포인트·랩 판정
  - 시뮬레이터에서 2초 뒤 자동으로 박스를 여는 임시 진단 코드로 런타임 크래시·에러 없음을 확인(확인 후 제거)
- [x] 모션 튜닝을 실제 트랙 스케일 기본값으로 복원하고 트랙 JSON `tuning` 오버라이드 지원 (위 항목에서 `MotionTuning().applying(track.tuning)`으로 구현)
- [ ] ECS 컴포넌트 6종 + 시스템 5종 구현 (테크 PRD 4장) — 지금은 RealityKit 컴포넌트/시스템이 아니라 `ImmersiveBoxView`의 `SceneEvents.Update` 콜백 하나에서 입력·모션·이탈·랩 판정을 순서대로 호출하는 방식. 실제 트랙 타일 엔티티/콜리전이 생기는 시점에 본격적인 ECS 분리가 필요
- [x] 벽 충돌 로직 (이슈 #9) — 타일 메시 콜리전 대신, 매 프레임 이미 계산하는 중심선 거리(`TrackPath.closestSegment`가 이제 투영점도 같이 반환)를 재사용해 `distance > tileSize/2`면 그 지점으로 되밀어내는 단순 모델로 구현. 처음 닿는 프레임에 `wallBump` 트리거. **단순화 주의**: 커브 안쪽 모서리에는 실제 벽이 없는데(이슈 #9) 이 모델은 좌우를 구분 안 해서 양쪽 다 막는다 — 실기기에서 커브 안쪽이 막혀 어색하면 다시 손봐야 한다
- [ ] **실기기 확인 필요**: 타일 회전(`rot`, 컴퍼스 시계방향으로 가정하고 부호를 뒤집어 적용 — `ImmersiveBoxView.buildTrackTiles` 주석 참고)이 실제로 인접 타일끼리 노면이 이어지는지. 안 맞으면 부호를 다시 뒤집는다
- [ ] **실기기 확인 필요**: 위 벽 충돌이 커브 안쪽에서 너무 막혀 어색한지, 타일 모서리 위치와 충돌 경계가 실제로 맞는지

## M4 — 미니맵

- [x] Diorama 샘플에서 받침 모델(`Diorama_Base.usdz`)만 이식, 트랙 JSON 중심선에서 지도 기하를 직접 생성(이미지 스크립트 대신 — 결정 48) — `RealityKit/MinimapBuilder.swift`, `KartCore/MinimapProjection.swift`
- [x] 동기화: `Minimap.update`(마커 위치·회전, 체크포인트 라벨 색, 랩 텍스트)를 `tickMotion`에서 호출. `RaceHUDState.kartMapPosition/kartHeading` 추가
- [x] 배치: 디오라마는 박스 앞오른쪽 모서리 위 지름 0.16, 콕핏은 HUD 오른쪽 아래 지름 0.24·35° 기울임 (결정 48)
- [ ] 실기기 확인: 위치·크기·가독성·마커 추종·콕핏 배치 (시뮬레이터 시각 확인 못 함)
- [ ] 보류: 체커 깃발, 높이맵·등고선, 통과 색 전환 애니메이션, 디자인 피드백 반영

## M5 — HUD·화면 흐름·효과음 (2026-10-10 RaceModel 1차 데이터 플러밍)

- [x] `RaceHUDState`/`RaceModel` 필드 구현 (테크 PRD 10장) — `KartCore/RaceHUDState.swift`, `RaceModel.swift`. `kartMapPosition`/`kartHeading`(미니맵용)와 `RaceEvent`(효과음용)는 M4·효과음 연결 시점에 추가
- [x] `ImmersiveBoxView`에 임시 HUD(`RaceHUDOverlay`, 2D `.overlay`)로 랩/타임/속도 표시, 센터라인 이탈 시 "트랙 이탈" 뱃지
- [ ] **알려진 문제**: 이머시브 스페이스가 열려 있는 동안 RealityView가 계속 렌더링 중이라, `raceModel`(Observable)을 어떤 스케줄(프레임 콜백/GCD/Task)로 갱신해도 SwiftUI가 "Modifying state during view update"를 로그에 남긴다(크래시는 아니고 HUD 값은 정상 갱신됨). 갱신 주기를 250ms로 늦춰 로그 노이즈만 줄여둔 상태 — 정식 해결은 아래 항목과 함께
- [x] HUD를 2D `.overlay`에서 `RealityView`의 3D attachment(entity에 붙는 SwiftUI 뷰)로 교체 (결정 25·26번)
- [x] 카운트다운 대기(3·2·1·GO 입력 잠금, HUD 큰 숫자) — Issue #41, 결정 56
- [x] 결과 화면(총 시간·랩별·신기록·다시 하기) — Issue #42, 결정 56
- [x] 배경음 3곡 연결(`Resources/BGM/`, `BGMPlayer` 머리 고정 재생, GO 1.0초 페이드 인 → 반복 → 완주 2.0초/종료 0.5초 페이드 아웃, 레이스마다 곡 순환, 버스 −6 dB) — 디자인 결정 55-1, 결정 56. 일시정지 덕킹(−10 dB)은 결정 57에서 연결
- [x] 시작 화면 트랙 선택(결정 57: track_01~03 → 결정 58에서 서킷 3종으로 교체) — 카드 3장(경로 썸네일·난이도 점·최고 기록), 박스 열린 채 교체 시 타일·미니맵·출발 재구성, 결과 패널 "트랙 선택" — Issue #43, 결정 57
- [x] 일시정지 패널(재개 카운트다운·다시 시작·박스 닫기, 주행 적분 정지, 엔진 `paused()`, 배경음 −10 dB) — Issue #44, 결정 57
- [ ] HUD 속도계 교체 — Issue #28(디자인 리소스 대기)
- [x] 효과음 7종 + 엔진음 5종 연결 — `Assets/sfx/ENGINE.md` 스펙대로 `EngineSoundMachine`/`EngineAudioPlayer`/`SFXPlayer` 구현 (결정 35번). `wallBump`는 M3 벽 충돌 로직 추가로 트리거 연결 완료 (결정 38번)
- [x] HUD/트랙 색을 `Design/style-guide.md` 팔레트로 교체 (결정 35번)
- [x] 제목에 Galmuri 픽셀 폰트 적용 (결정 35번, 디자인 결정 20-3·20-5)
- [x] 핀치 상태 HUD(양손 점 + 중앙 방향 아이콘 + 세로 페달 게이지, cyan=전진/magenta=후진 6상태) — `RaceHUDOverlay`의 `PinchStatusView`/`PedalGaugeBar` (디자인 PRD 7장, 결정 37번)
- [x] 조작법 화면(이슈 #12) — `ContentView`의 "조작법" 버튼 + 첫 실행 시 자동 표시(`@AppStorage("hasSeenOnboarding")`), 손 그림 5장(SVG를 Asset Catalog 벡터 이미지로) + 중립 안내 (결정 38번). 결정 39·41로 모드별 세그먼트가 되어 디오라마 5장·1인칭 2장·3인칭 4장 그림(디자인 결정 40)을 연결했고, "40 cm 중립" 문구는 "핀치 시작 간격 기준"으로 바꿨다. 단, 위 "메뉴 4화면" 전체(시작/대기/카운트다운/결과 등)는 아직 아니고 조작법 1장만

## 서킷 3종 — 3D 스플라인 트랙·레일 주행·테마 (2026-10-12, 결정 58)

- [x] 트랙 스키마 2 생성기 `Tracks/tools/gen_circuit.py`(직선·경사·호/뱅크·수직 루프·헬릭스 + 두빈스 닫기, 닫힘·입체 교차·간격 검사)
- [x] 서킷 3종 JSON: `circuit_01` 루키 오벌(공원, easy), `circuit_02` 리본 루프(네온 나이트, normal, 360° 루프·시케인·헤어핀), `circuit_03` 스카이 스파이럴(사막 협곡, hard, 오르막·브리지·헬릭스·더블 시케인·뱅크 스위퍼)
- [x] 노면 메시 빌더 `Tools/build_circuit.py`(헤드리스 Blender → USDZ + 확인 렌더, 테마 팔레트·소품·기둥·출발선)
- [x] `TrackSpline`·`RailMotionState`·`KartPose`(곡률 드리프트, 안쪽 라인, 중력, 벽 미끄러짐, 루프 자세) + 테스트 16개(서킷 통합 자동 조향 포함)
- [x] `ImmersiveBoxView` 레일 주행 전환, 서킷 USDZ 로드, 3인칭 3D 추적(루프에서 heading 유지), 디오라마 높이 배율
- [x] 카탈로그 4종(기존 '첫 바퀴' + 서킷 3) · 번들 리소스 누락(JSON 미복사 → 박스에 아무것도 안 보임) 수정 + `TrackResourceTests`
- [x] 미니맵 테마 색·고가 띠·특징 라벨, 시작 화면 카드 난이도 점·특징 태그
- [ ] 실기기: 루프·헬릭스·뱅크 체감, 3인칭 루프 카메라(세계가 돌지 않는지), 중력 4.5·벽 감속 튜닝, 노면 USDZ 방향·소품
- [ ] 후속 아이디어: 점프대(공중 구간), 부스터 패드, 트랙별 고스트 기록, 서킷 썸네일을 Blender 렌더로 교체

## 디자인 PR #57 반영 — 아이콘·속도계·카운트다운 음원·풍차·랩 배너·운전자 (2026-10-14, 결정 65)

- [x] #58 정식 앱 아이콘(가스펠 3층·iOS 1024) 적용, 자리표시자 생성기 삭제
- [x] #59 속도계 레이어 + 연속 게이지 + 부스트 프레임(`SpeedometerView`, visionOS·iOS HUD)
- [x] #60 준비음·출발음 M4A, 3.1초 간격·GO 9.3초(`RaceTiming`), 인스턴스 정리(`SFXPlayer.stopAll`)
- [x] #61 풍차 Bedrock → USDZ(`bedrock2usdz.py`), 루키 오벌 외곽 2기, 날개·보조날개 런타임 회전
- [x] #62 카운트다운 그림·랩 배너(2~99·FINAL LAP)·UI 소리 3종(랩·신기록·오류) 연결 — 방향 안내판·가로 게이지·패드는 보류
- [x] #63 운전자 kart_idle 클립 USDZ, 가스펠 착석 부착(배율 한 번) — 조향 연동·4종 피팅은 후속
- [ ] 실기기: 준비음 간격·음량, 속도계 가독성, 풍차 회전 방향, 운전자 좌석 정렬, Vision Pro 홈 화면 아이콘

## 속도계 가운데 아래 · 데모 실행 모드 · 시뮬레이터 캡처 (2026-10-14, 결정 66)

- [x] 속도계를 visionOS HUD 패널·iOS 화면 모두 가운데 아래로(랩 패널에서 분리)
- [x] visionOS 속도계를 별도 attachment로 — 3인칭은 카트 내림각 +16° 방향 1 m(카트 아래, 시야 하단 중앙, 머리 따라옴), 디오라마는 박스 앞면 아래 가운데
- [x] DEBUG 데모 실행 인자(`-demoTrack -demoMode -demoAutopilot`), `Autopilot` 공용화(테스트·visionOS·iOS), 시뮬레이터 3인칭 데모 카메라
- [x] Vision Pro 시뮬레이터 캡처 6장(`Docs/review/vision-sim/`) — 리본 루프 360° 루프 4장, 스카이 스파이럴 헬릭스 2장 → README "서킷 3종" 절
- [x] iPhone 시뮬레이터 플레이 캡처 6장(`Docs/review/ios/iphone-*.jpg`, `-demoMode topView|chase`) → README 상단 "플레이 촬영컷" 요약 + "iPhone 플레이 캡처" 갤러리
- [x] iPhone 시뮬레이터 플레이 캡처 6장(`Docs/review/ios/iphone-*.jpg`, `-demoMode topView|chase`) → README 상단 "플레이 촬영컷" 요약 + "iPhone 플레이 캡처" 갤러리
- [ ] 실기기: 속도계 위치·크기 체감(Vision Pro 3인칭 여유각 16°·디오라마 박스 아래, iPhone), 디오라마 모드 캡처는 실기기로

## M6 — 폴리시 · 출시 준비 (GitHub 마일스톤 "M6 — 출시 준비": Issue #45·#46)

- [x] 성능 예산 측정 — 자체 측정기(`FrameTimeSampler`+`MemoryFootprint` PERF 로그, 결정 61)로 시뮬레이터 수치 기록(`Docs/review/perf_2026-10-12.md`), 미니맵 리본 메시 병합·타일 반경 컬링(결정 59). 실기기 Instruments 표는 후속(다듬기)
- [x] 앱 이름 확정 → '핀치 로버'(Pinch Rover), 결정 53. `CFBundleDisplayName`·제목·LICENSE·README 반영, 디자인 문서(PRD 1·15장, `app-name.md`, 목업 01)는 디자인 요청
- [x] 아카이브 크기 측정(리소스 51 MB, 결정 59) · [x] 메모리 PERF 로그(결정 61) · [x] 디버그 로그 `debugLog()` 플래그 · [x] 접근성 라벨 · [x] 앱 아이콘 자리표시자(`Tools/make_app_icon.py`) + 스토어 자산 초안(`Docs/store/listing.md`) — 정식 아이콘·스크린샷은 디자인 후속

## iOS/iPadOS 버전 (GitHub 마일스톤 "iOS/iPadOS 버전", 결정 56 — M6 뒤)

- [x] #47 Epic: KartCore 공유, 입력·카메라만 교체 — 결정 60
- [x] #48 같은 앱 타깃을 iOS로 빌드(SUPPORTED_PLATFORMS 기존 설정), KartCore·RealityKit 도우미 공유, 메뉴·온보딩 재사용
- [x] #49 터치 조작(`TouchInputResolver`, 핀치 규칙 1:1), 터치 존 2개 + 핀치 상태 필. 디자인에 터치 조작 그림은 추후 요청
- [x] #50 탑뷰·추적 카메라(`ChaseCameraRig`, RealityView 가상 카메라), HUD 오버레이, 2D 미니맵(`TrackPlanCanvas`)
- [x] #51 (선택) AR 모드 — 평면 앵커 + 디오라마 배율, **실기기 미확인**
- [ ] 실기기(iPhone/iPad): 두 엄지 조작 감각, 추적 카메라 멀미, AR 평면 인식, 아이패드 가로 레이아웃

## 열린 질문 (결정되면 `Docs/decisions.md`에 기록)

- [x] 박스 다이오라마의 실제 치수 — `0.7×0.4×0.7m`로 확정 (결정 34번, 디자인 결정 20-10 답변)
- [x] 카트 로스터 — `arcrix`/`bogubkart`/`gospel`/`razr`/`sirius` 5종 확정, `mms` 제외 (결정 34번, 디자인 결정 20-7·20-8)
- [x] `mms` 포함 여부 — 제외, 리소스 파일도 삭제 (위와 동일)
- [x] 메뉴 카트 360도 회전 — `Model3D` + 드래그 제스처로 구현 (결정 34번, 디자인 결정 20-9)
- [ ] Digital Crown 몰입도 범위(현재 0.0~1.0 임시값)를 얼마로 둘지, 레이싱 중에도 조절 허용할지
- [ ] M2 모션 튜닝 임시값(박스 스케일)을 M3에서 트랙 스케일로 복원할 때 느낌이 달라지는지 재검증 필요
- [x] Galmuri 폰트 파일, 엔진음 루프 사운드, RetireX 색 팔레트 — 전달받아 반영 완료 (결정 35번)
- [x] 타일 대체 텍스처(`Design/textures/`, 결정 21번) — 타일 USDZ가 `tiles.png`를 그대로 갖고 있어 추가 적용 불필요로 판단 (결정 38 "반영 안 함")
- [x] 색상 스와치 지름/간격 — 40 pt / 14 pt를 정식 값으로 확정, 스타일 가이드 1-3 수정됨 (디자인 결정 36-3)
