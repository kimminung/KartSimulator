# 결정 기록

번호 · 결정 · 날짜 · 이유 순으로 적는다. PRD의 표에 번호가 있는 결정은 같은 번호를 쓴다.

> **번호 20·21이 두 번 나온다**: Dev(테크)와 main/design(디자인)이 각자 결정 19번 다음부터 독립적으로
> 번호를 매기다 보니 둘 다 20·21을 썼다. 먼저 나오는 20·21은 테크 결정(제스처 버그, 디버그 도구)이고,
> 나중에 다시 나오는 20·21(각 항목에 "결정자: 디자인"이 적혀 있다)은 디자인 결정 묶음·바닐라 텍스처
> 금지다. "디자인 결정 20-11" 같은 하위 항목 참조가 `Design/`·`Docs/`·코드 주석에 이미 많이 퍼져
> 있어서 번호를 다시 매기지 않고 그대로 둔다.

## 13. 공간 구성: ImmersiveSpace + 박스 프레임 다이오라마

- **날짜**: 2026-10-10
- **결정**: 테크 PRD 1장 결정 1번("볼륨 테이블탑, Volumetric WindowGroup")을 `ImmersiveSpace` + `.immersionStyle(selection:in: .progressive)`로 바꾼다. 트랙/카트 콘텐츠는 박스 모양 프레임(와이어프레임 엣지 + 바닥판)으로 경계를 표시해 "책상 위 디오라마" 컨셉은 유지한다.
- **이유**: 사용자가 Digital Crown을 돌려 이머시브 공간과 바깥(패스스루)을 번갈아 볼 수 있어야 한다는 요구사항 때문. `progressive` 몰입 스타일이 정확히 이 동작(크라운으로 몰입도 0~1 조절)을 기본 제공한다. Volumetric WindowGroup에는 이 몰입도 다이얼 개념이 없다.
- **영향받는 절**: 테크 PRD 3, 5, 9, 12장 (볼륨 좌표계 설명은 이머시브 박스 좌표계로 재해석 필요)

## 14. 카트 에셋: 완성형 USDZ 6종 로스터

- **날짜**: 2026-10-10
- **결정**: 디자인 PRD 4장의 Blockbench 단일 카트(`kart_01`) 파이프라인 대신, 완성형 USDZ 6종(`arcrix`, `bogubkart`, `gospel`, `mms`, `razr`, `sirius`)을 1차 카트 로스터로 채택한다. `mms`를 제외한 5종은 색상 16종(`black`/`blue`/`brown`/`cyan`/`gray`/`green`/`light_blue`/`lime`/`magenta`/`orange`/`pink`/`purple`/`red`/`silver`/`undyed`/`white`/`yellow`) 텍스처 변형을 포함한다.
- **이유**: 테크가 직접 6종 USDZ를 전달받아 즉시 쓸 수 있는 상태(원점·텍스처 포함)이므로, Blockbench→glb→USDZ 변환 파이프라인을 1차로는 생략하고 바로 통합한다.
- **영향받는 절**: 디자인 PRD 4·12·13장(카트 전달 규칙), 테크 PRD 8장(에셋 파이프라인 — 카트는 변환 불필요, 트랙 타일은 기존 파이프라인 유지)
- **열린 질문**: `mms`는 색상 변형이 없고 텍스처 용량이 크다(약 30MB). 최종 로스터 포함 여부는 `Docs/TechTask.md` 열린 질문 참고.

## 15. 플랫폼: 기존 visionOS 지원 유지

- **날짜**: 2026-10-10
- **결정**: Xcode 템플릿이 이미 멀티플랫폼(iOS·macOS·visionOS) 타깃으로 생성되어 있었다. 별도 타깃을 새로 만들지 않고, 기존 타깃에서 visionOS 전용 코드는 `#if os(visionOS)`로 가드한다.
- **이유**: `SUPPORTED_PLATFORMS`에 `xros`/`xrsimulator`가 이미 포함되어 있어 추가 설정 없이 바로 visionOS 시뮬레이터로 빌드 가능했음.

## 16. KartCore 위치: 앱 타깃 내 폴더 + 호스트형 테스트 타깃

- **날짜**: 2026-10-10
- **결정**: 테크 PRD 3장이 제안한 별도 SPM 패키지(`KartCore` Swift Package) 대신, `KartSimulator` 앱 타깃 안의 `KartCore/` 폴더에 플랫폼 독립 로직(RealityKit·SwiftUI를 import하지 않는 순수 Swift)을 둔다. 단위 테스트는 `KartCoreTests`라는 호스트형(Hosted) 유닛 테스트 타깃(Swift Testing, `TEST_HOST`를 KartSimulator.app으로 지정)에서 `@testable import KartSimulator`로 접근해 검증한다.
- **이유**: 파일시스템 동기화 그룹(PBXFileSystemSynchronizedRootGroup) 기반 프로젝트에서 로컬 SPM 패키지 참조를 pbxproj에 안전하게 추가할 도구가 없어, 더 간단하고 사고 위험이 적은 방식을 택했다. 모듈 경계는 약해지지만(별도 모듈이 아님), "RealityKit 없이 macOS에서 로직 테스트" 라는 원래 목표는 테스트 스킴을 macOS 대상으로 바꾸면 동일하게 달성된다.
- **영향받는 절**: 테크 PRD 3장(모듈 구성 표 — `KartCore` 행을 "앱 타깃 내 폴더"로 읽는다), 12장(단위 테스트 — `KartCoreTests`가 담당)
- **구현 완료**: `DriveState`, `InputTuning`, `MotionTuning`, `HandInputResolver`, `KartMotionState` + 단위 테스트 13개(`KartCoreTests`), `ImmersiveBoxView`에서 `SpatialEventGesture` 입력을 실제로 연결해 박스 안에서 카트가 주행하는 것까지 확인.

## 17. 트랙 생성 난이도: "목표 커브 수" 대신 "노치 개수"로 조절

- **날짜**: 2026-10-10
- **결정**: `Tracks/tools/gen_track.py`의 난이도 파라미터를 테크 PRD 7장의 "easy 커브 4개/normal 6개/hard 8개 이상"이라는 목표 커브 수가 아니라, 삽입할 "노치(notch) 개수"로 정의한다. `easy=노치 0(커브 4개)`, `normal=노치 1(커브 8개)`, `hard=노치 2(커브 12개)`.
- **이유**: 사각 루프 변의 일부를 바깥으로 밀어내는 노치 1개를 넣으면, 새로 생기는 코너 2개뿐 아니라 노치 양옆의 기존 직선 타일 2개도 진입/진출 방향이 꺾이며 커브로 바뀐다 — 즉 노치 1개당 커브가 정확히 +4개 늘어난다(+2가 아니다). 이 때문에 이 구현에서 나올 수 있는 커브 수는 4, 8, 12, …뿐이고, PRD가 예시로 든 "normal 6개"는 애초에 나올 수 없다. "hard 8개 이상"은 normal(8개)에서 이미 만족되므로, 실제로 차이를 두려면 hard는 12개로 둔다.
- **영향받는 절**: 테크 PRD 7장("난이도" 설명 — easy/normal/hard의 커브 개수는 "대략" 4/8/12로 읽는다. 구조적 정합성(검증 스크립트 5종 통과)은 커브 개수와 무관하게 항상 보장된다)
- **검증**: easy/normal/hard × seed 8종(1~8), 8×6 그리드로 `gen_track.py` → `validate_track.py` 24회 전부 통과. `Tracks/track_01.json`(easy), `Tracks/track_02.json`(normal) 커밋.

## 18. 버그 수정: "박스 열기" 버튼이 아무 반응 없던 문제

- **날짜**: 2026-10-10
- **증상**: 메뉴에서 "박스 열기"를 눌러도 이머시브 공간이 열리지 않고 아무 반응이 없었다.
- **원인**: `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` 빌드 설정이 `[sdk=iphoneos*]`/`[sdk=iphonesimulator*]` 조건에만 걸려 있어 visionOS(xros/xrsimulator) SDK에는 적용되지 않았다. 그 결과 visionOS용 Info.plist에 `UIApplicationSceneManifest`(멀티 씬 지원 선언)가 생성되지 않았고, `openImmersiveSpace(id:)`가 콘솔에 "Unable to open an immersive space when the app does not support multiple scenes" 폴트를 내며 항상 `.error`를 반환했다. 코드가 그 결과를 무시하고 있어서 UI에는 아무 변화도 나타나지 않았다.
- **진단 방법**: `ContentView`에 임시로 `openImmersiveSpace` 결과를 `print`하고 2초 뒤 자동 호출하는 코드를 넣어 시뮬레이터에서 실행 → 콘솔에서 정확한 폴트 메시지를 확인한 뒤 원인을 찾고 임시 코드는 제거했다.
- **수정**: `INFOPLIST_KEY_UIApplicationSceneManifest_Generation`을 플랫폼 조건 없이 `YES`로 설정(모든 플랫폼에 적용). 이후 `openImmersiveSpace` 결과가 `.opened`로 정상 반환되는 것을 시뮬레이터에서 확인.
- **영향받는 절**: 테크 PRD 3장(앱 구조 — `RaceVolume`/`ImmersiveSpace` 씬), 결정 13번(ImmersiveSpace 전환)

## 19. 박스 안 주행을 실제 트랙 좌표계로 전환

- **날짜**: 2026-10-10
- **결정**: M2에서 만든 "박스 바닥 전체를 임시 주행장으로 쓰고 벽에 닿으면 반사"하는 방식을 버리고, `Tracks/track_01.json`을 실제로 읽어 그 좌표계·체크포인트·랩 규칙대로 주행하게 바꿨다. 트랙의 월드 바운딩 박스를 박스 바닥 폭(0.6m)에 맞추는 배율(`trackDisplayScale`)을 한 번 계산해, 트랙 시각화와 카트 스케일에 **같은 배율**을 써서 비례를 맞춘다.
- **이유**: M3가 "박스 임시 주행장 → 실제 트랙 좌표계·타일 배치로 교체"를 명시적으로 요구했고, 카트 전용 고정 크기(22cm)를 계속 쓰면 트랙이 생기는 순간 카트와 트랙의 비례가 어긋나기 때문.
- **타협점**: 트랙 타일 3D 에셋이 아직 없어서, 타일을 깔지 않고 `path`를 작은 점(큐브) 점열로만 시각화한다. 벽도 아직 없어 `CollisionResolveSystem`에 해당하는 벽 충돌 로직은 구현하지 않았다(테크 PRD 12장 "벽에 정면으로 박았을 때 미끄러진다" 체크리스트는 타일 에셋 확보 후).
- **영향받는 절**: 테크 PRD 7장(트랙 데이터), 9장(배율 — 기존 0.04 고정값 대신 트랙마다 자동 계산), `Docs/TechTask.md` M3

## 20. [테크] 버그 수정: 박스 연 뒤 핀치 제스처가 완전히 무반응이던 문제

- **날짜**: 2026-10-10
- **증상**: 실기기에서 "박스 열기" 후 양손 핀치를 해도 카트가 전혀 반응하지 않았다(완전 무반응).
- **원인**: `ImmersiveBoxView`의 `driveGesture`가 `SpatialEventGesture()`를 어떤 엔티티도 조준하지 않은 채(`.targetedToEntity`/`.targetedToAnyEntity` 없이) 붙이고 있었다. RealityKit 공식 가이드("Responding to gestures on an entity")에 따르면 `RealityView` 안에서 제스처가 발생하려면 대상 엔티티에 `InputTargetComponent` + `CollisionComponent`가 반드시 있어야 하는데, 이 프로젝트에는 그런 엔티티가 아예 없었다. 테크 PRD 5장에 적어 둔 "InputCatcher" 엔티티를 실제로는 만들지 않고 넘어간 것이 원인 — PRD에 쓰기만 하고 구현을 빠뜨렸다.
- **진단 방법**: Apple 문서에서 `targetedToAnyEntity`/`InputTargetComponent` 관련 공식 가이드("Responding to gestures on an entity")를 확인해 "InputTargetComponent + CollisionComponent가 있는 엔티티만 이벤트를 받는다"는 조건을 재확인.
- **수정**: `inputCatcher`라는 보이지 않는 엔티티를 박스 위치에 두고 박스보다 넉넉한 크기(`boxSize * 3`)의 `CollisionComponent` + `InputTargetComponent`를 부여, `driveGesture`를 `SpatialEventGesture().targetedToEntity(inputCatcher)`로 바꿨다. 시뮬레이터에서 빌드·실행·유닛 테스트 23개 재확인 완료 — 다만 실제 손 핀치 인식 자체는 시뮬레이터로 검증 불가하므로 실기기 확인이 필요하다.
- **영향받는 절**: 테크 PRD 5장("InputCatcher" 설계를 실제로 구현), `Docs/TechTask.md` M2

## 21. [테크] 실기기 제스처 디버그 도구 추가 (임시)

- **날짜**: 2026-10-10
- **결정**: `ImmersiveBoxView`에 실기기 전용 디버그 시각화를 임시로 추가했다. `ARKitSession` + `WorldTrackingProvider`로 헤드 앵커를 매 프레임 조회해, 머리 위치에 노란 구슬을, 기기 정면(로컬 -Z) 방향으로 초록 막대(3m)를 띄운다. 또한 `ingest()`에 `DEBUG-GESTURE` 태그를 붙인 `print`를 추가해, 들어오는 모든 핀치 이벤트의 `chirality`(LEFT/RIGHT)·`phase`·`pinching`·위치를 로그로 남긴다.
- **이유**: 결정 20번에서 "제스처 무반응" 버그를 코드 추론만으로 고쳤는데, 실기기에서 진짜로 손을 구분해서 받는지는 아직 직접 확인하지 못했다. 사용자가 실기기를 착용한 채로는 Xcode 콘솔을 볼 수 없으므로, (1) 눈으로 볼 수 있는 시선 레이로 "박스 쪽을 보고 있는지" 스스로 확인하고, (2) 터치 시 남는 로그를 테크(Claude)가 나중에 읽어 왼손/오른손이 각각 어떻게 인식됐는지 판단한다.
- **필요 설정**: `INFOPLIST_KEY_NSWorldSensingUsageDescription`을 추가했다(헤드 트래킹에 월드 센싱 권한이 필요). 첫 실행 시 권한 팝업이 뜰 수 있다 — 허용해야 디버그 레이가 보인다.
- **확인**: 시뮬레이터에서 빌드·실행·유닛 테스트 23개 재확인. 시뮬레이터의 포인터 기반 입력으로 `DEBUG-GESTURE LEFT`/`RIGHT`가 `phase`(active→ended)와 함께 정상적으로 구분되어 찍히는 것까지 확인 — 제스처 조준 자체는 정상 작동. 실제 손 인식 품질은 실기기에서만 확인 가능.
- **제거 예정**: 이 섹션 관련 코드는 모두 "디버그 전용" 주석으로 표시해 뒀다. 문제 파악이 끝나면 `ImmersiveBoxView`에서 통째로 제거한다.
- **영향받는 절**: `Docs/TechTask.md` M2 (실기기 테스트 체크리스트)

## 22. 버그 수정: 실기기에서 "차가 움직이지 않는다"던 문제 — 실제로는 너무 작아서 안 보였던 것

- **날짜**: 2026-10-10
- **증상**: 결정 20번(제스처 무반응) 수정 후, 실기기에서 양손 핀치를 해도 카트가 움직이지 않는다는 리포트.
- **진단**: 결정 21번에서 추가한 `DEBUG-GESTURE` 로그를 실기기 테스트 세션 2회(`GetConsoleOutput`)에서 직접 확인. 결과: 왼손/오른손 핀치 이벤트가 `chirality` 정상 구분되어 들어오고, 양손이 동시에 `pinching=true`로 상당 시간(여러 프레임) 겹치는 것도 확인됨 — 즉 입력 파이프라인(`HandInputResolver.resolve` → `forwardFull`)은 정상 작동 중이었다. 트랙(`track_01.json`)·카트 USDZ 로드 실패 로그도 전혀 없었다(둘 다 정상 로드). 코드를 추적한 결과, 결정 19번에서 트랙 시각화와 카트 스케일에 "같은 배율"(`trackDisplayScale`)을 쓰기로 한 선택이 문제였다: `track_01.json`은 월드 기준 20m 폭 트랙이라 `trackDisplayScale`이 0.03까지 내려가고, 카트 USDZ(실물 크기 기준)에 그대로 곱하면 카트 길이가 3cm 안팎까지 줄어든다 — 박스(0.7m) 안에서 거의 안 보이는 크기라 "움직이는지 안 움직이는지" 식별이 불가능했다. 로직 자체는 정상, 시각적으로 인지 불가능했던 문제.
- **수정**: 카트의 "보이는 크기"와 "트랙 위 이동 배율"을 분리했다. `loadKart()`에서 `KartFitter.fit(entity, scale: trackDisplayScale)` 대신 `KartFitter.fit(entity, maxDimension: kartVisualLength)`(0.12m, 고정값)을 쓴다. 카트가 트랙 좌표를 따라 이동하는 위치 계산(`worldToDisplay`, `kartSlot.position`)은 그대로 `trackDisplayScale`을 쓰므로 트랙 대비 이동 비율은 변하지 않고, 카트 자체만 항상 보이는 크기를 유지한다.
- **덧붙여 확인된 부가 이슈(아직 미수정)**: 핀치 중 실측된 양손 간 거리가 보통 0.6~0.7m로, `InputTuning.spreadFull`(0.40m)을 가볍게 넘는다 — 즉 양손을 벌려 핀치하면 거의 항상 즉시 `forwardFull`이 되어 "절반 속도" 단계가 체감되지 않을 수 있다. 움직임 자체과는 무관한 튜닝 문제라 이번엔 건드리지 않았고, 실기기로 움직임이 보이는지 먼저 확인한 뒤 필요하면 `spreadHalf`/`spreadFull` 값을 올린다.
- **영향받는 절**: 결정 19번(배율 공유 방식 수정), `Docs/TechTask.md` M2/M3

## 23. 실기기 디버그 도구 추가: 이동량 로그 + 주행 경로(빨간 선) (임시)

- **날짜**: 2026-10-10
- **결정**: `ImmersiveBoxView`에 두 가지를 임시로 추가했다. (1) `tickMotion`에서 매 프레임 계산되는 `drive`/`speed`/`position`/누적 이동거리를 0.25초 간격으로 `DEBUG-MOTION` 태그로 `print`한다. (2) 카트가 실제로 지나간 박스 바닥 좌표를 3mm 이상 움직일 때마다 빨간 막대 하나로 이어 붙여(`trailRoot`에 계속 추가) 경로를 눈으로 볼 수 있게 한다.
- **이유**: 결정 22번으로 "카트가 너무 작아서 안 보였다"는 원인을 찾아 고쳤지만, 실기기에서 핀치 후 실제로 몇 m/s로, 얼마나 이동했는지 수치로도 확인하고, 이동 경로 자체가 트랙을 따라가는지 시각적으로도 확인할 수 있어야 한다. `DEBUG-GESTURE`(결정 21번)와 `DEBUG-MOTION` 로그를 같이 읽으면 "핀치가 들어온 뒤 실제로 속도가 올라갔는지"까지 한 번에 추적할 수 있다.
- **구현 메모**: 로그는 매 프레임이 아니라 0.25초마다 찍어 콘솔 노이즈를 줄였다. 경로 선은 세그먼트 최소 길이(3mm)를 둬서 정지해 있을 때 세그먼트가 과도하게 쌓이지 않게 했다. 시간이 오래 지나면 세그먼트 엔티티 수가 계속 늘어나는 점은 디버그 전용이라 신경 쓰지 않았다(원인 파악 끝나면 통째로 제거).
- **제거 예정**: `MARK: - 디버그 전용: 주행 경로(빨간 선) + 이동량 로그` 섹션과 `tickMotion` 안의 관련 블록, `addTrailSegment` 전부. 결정 21번 디버그 코드와 함께 한 번에 정리한다.
- **영향받는 절**: 결정 22번, `Docs/TechTask.md` M2/M3

## 24. 버그 수정: 실기기에서 핀치를 해도 `drive`가 영원히 `.stopped`였던 진짜 원인 — 시계 기준 불일치

- **날짜**: 2026-10-10
- **증상**: 결정 23번에서 추가한 `DEBUG-MOTION` 로그를 실기기 "방금 켠" 세션에서 직접 확인해 보니, `DEBUG-GESTURE`는 오른손 핀치가 계속 들어오는데도 `DEBUG-MOTION`은 처음부터 끝까지(수백 줄, 2분 이상) `drive=stopped speed=0.0 pos=(시작점 그대로)`로 전혀 변하지 않았다.
- **원인**: `ingest()`가 `HandSample(..., timestamp: event.timestamp)`로 SwiftUI `SpatialEventCollection.Event`의 자체 시계를 저장하는데, `tickMotion()`은 `HandInputResolver.resolve(now:)`를 호출할 때 `Date().timeIntervalSinceReferenceDate`(2001년 기준 초)를 넘기고 있었다. 두 시계는 기준 시점이 전혀 다르다 — `event.timestamp`는 (Apple 공식 샘플 "Petite Asteroids"에서도 다른 `event.timestamp`끼리만 빼서 `duration`을 구하듯) 제스처 시스템 자체의 시계이고, `Date()` 기준 "2026년"은 초 단위로 7억 초가 넘는 값이다. `HandInputResolver.status(for:now:)`는 `now - hand.lastEventTime`이 `staleTimeout`(0.3초)보다 크면 그 손을 "추적 안 됨"으로 간주하는데, 두 시계를 섞어 쓰면 이 차이가 항상 수억 초가 되어 **모든 핀치가 항상 스테일로 판정되고, `determineState`는 영원히 `(false, false) → .stopped`만 반환**한다. 즉 결정 20·22번을 거치며 입력 전달과 카트 크기는 다 고쳤지만, 그 사이에도 주행 로직 자체는 실기기에서 단 한 번도 제대로 작동한 적이 없었다 — 로그 비교가 없었다면 계속 몰랐을 버그.
- **수정**: `ingest()`에서 `HandSample`을 만들 때 `timestamp: event.timestamp` 대신 받는 즉시 `CACurrentMediaTime()`으로 다시 찍고, `tickMotion()`의 `now`도 `Date().timeIntervalSinceReferenceDate` 대신 `CACurrentMediaTime()`으로 바꿔 두 값이 항상 같은 시계를 쓰게 했다(이미 `updateHeadDebugGizmo()`에서 쓰고 있던 시계와 동일).
- **영향받는 절**: 결정 20·21·22·23번(모두 같은 파일 수정 과정에서 나온 결정), `Docs/TechTask.md` M2

## 25. HUD를 `.overlay()` 대신 RealityView 3D attachment로 전환 (박스 위에 고정)

- **날짜**: 2026-10-10
- **증상**: 속도/랩 HUD가 화면 기준 `.overlay(alignment: .top)`로 떠 있었는데, 실기기에서 보면 뷰포트 상단이 아니라 사용자 발밑 근처에 표시됐다. 이머시브 스페이스 안에서 평범한 SwiftUI `.overlay()`는 (윈도우가 있는 `WindowGroup`과 달리) 머리에 고정된 뷰포트 기준으로 그려지지 않는다는 뜻.
- **수정**: `RealityView(make:update:attachments:)` 형태로 바꾸고, HUD(`RaceHUDOverlay`)를 `Attachment(id: "hud")`로 선언해 `attachments.entity(for: "hud")`로 꺼낸 엔티티를 박스 바로 위(`hudPosition` = 박스 위치에서 위로 0.15m)에 `content.add(...)`로 직접 배치했다. 항상 사용자를 향하도록 `BillboardComponent`도 붙였다. 결정 16번(M5)에서 "정식 해결책은 3D attachment로 바꿀 때"라고 적어 둔 것을 이번에 실제로 적용했다.
- **영향받는 절**: `Docs/TechTask.md` M5(HUD 배치 — 2D overlay 한계 해결)

## 26. 창의 "박스 닫기" 호버 불안정 수정: InputCatcher 축소 + HUD에도 닫기 버튼 추가

- **날짜**: 2026-10-10
- **증상**: 박스를 연 뒤 처음 창(`ContentView`)의 "박스 닫기" 버튼을 바라봐도 호버가 잘 안 잡히고, 고개를 바짝 들이대야 겨우 눌렸다.
- **원인**: `inputCatcher`의 충돌 범위가 `boxSize * 3`(약 2.1×1.2×2.1m, 결정 20번)으로 박스 주변을 거의 방 하나만큼 덮고 있었다. 이 보이지 않는 콜라이더가 사용자 정면(박스는 1.1m 앞)에 떠 있는 창의 히트테스트 영역과 깊이상 겹쳐서, 시선 레이가 창 유리보다 먼저 `inputCatcher`를 맞히는 바람에 창 버튼 호버가 가로채였다.
- **수정**: 두 가지를 같이 했다. (1) `inputCatcher` 충돌 크기를 `boxSize * 3` → `boxSize * 1.4`로 줄여 겹치는 범위를 크게 줄였다. (2) 창 버튼에만 의존하지 않도록, 박스 위에 떠 있는 HUD 패널(결정 25번) 안에도 "박스 닫기" 버튼을 넣었다 — 이 패널은 다른 콜라이더와 안 겹치는 공간에 있어 바라보고 누르기 안정적이다. 창과 이머시브 공간 양쪽에서 같은 "열림" 상태를 보려면 상태를 공유해야 해서, `isImmersiveOpen`을 `ContentView`의 로컬 `@State`에서 새 공유 모델 `ImmersiveSessionModel`(환경 객체)로 옮겼다 — 이머시브 공간 안에서 HUD 버튼으로 닫아도 창의 버튼 라벨이 "박스 열기"로 바로 맞게 바뀐다.
- **영향받는 절**: 결정 20번(InputCatcher 최초 도입), 결정 25번(HUD attachment), `Docs/TechTask.md` M2/M5

## 27. 전진/후진 방향 반전 수정 + 후진 제스처 추가

- **날짜**: 2026-10-10
- **증상**: 전진 입력을 줘도 카트가 반대 방향(후진)으로 달렸다. 사용자가 "에셋의 축이 다른 것 아니냐"고 직접 의심.
- **진단**: `kartSlot.orientation = simd_quatf(angle: heading, axis: Y)`와 `forward = (-sin(heading), 0, -cos(heading))`를 직접 전개해 보면 두 식이 정확히 일치한다 — 즉 "모델의 정면이 로컬 -Z"라는 전제 하에서는 주행 수학 자체가 자기 일관적이다(카트가 바라보는 방향 = 실제로 나아가는 방향). 따라서 반전의 원인은 모션 로직이 아니라, 이 USDZ 로스터가 정면을 로컬 +Z로 export해서 생긴 것으로 판단 — 사용자의 추측이 맞았다.
- **수정**: `KartModel`에 `modelForwardCorrectionDegrees`(기본 180도)를 추가하고, `loadKart()`에서 `KartFitter.fit(...)` 뒤에 로드된 엔티티 자체에 이 보정 회전을 한 번 더 준다. `kartSlot`의 회전(주행 방향 계산)은 그대로 둬서, 주행 수학과 "모델 생김새 보정"을 분리했다 — 나중에 카트별로 export 방향이 다르면 각 `KartModel`마다 값만 다르게 주면 된다.
- **후진 제스처 추가**: 양손을 핀치한 채 거리가 `InputTuning.reverseThreshold`(0.12m) 이하로 가까워지면 `.reverse`로 판정한다(`HandInputResolver.twoHandState`). 손 사이 거리를 "페달"로 쓰는 기존 설계(가깝게 → 후진, 적당히 → 대기, 멀리 → 절반/전체 전진)를 그대로 확장한 것이라 새 제스처 인식 코드가 거의 필요 없었다. `KartMotionState`는 `.reverse`일 때 목표 속도를 `-maxSpeed * reverseSpeedFactor`(기본 0.5, 즉 전진 최고속의 절반)로 두고 `brakeDecel` 비율로 접근한다. 속도계(HUD)에는 방향 없이 크기만 보여준다(`abs`) — 방향은 HUD의 `drive` 상태로 구분.
- **영향받는 절**: `DriveState`(`.reverse` 추가), `InputTuning`(`reverseThreshold`), `MotionTuning`(`reverseSpeedFactor`), `KartCatalog`(`modelForwardCorrectionDegrees`), `KartCoreTests`(관련 테스트 2개 추가), `Docs/TechTask.md` M2/M3

## 28. 후진 제스처 방향을 반대로 뒤집음: 좁힐수록 전진, 벌릴수록 후진

- **날짜**: 2026-10-10
- **결정**: 결정 27번에서 만든 "가깝게 모으면 후진, 멀리 벌리면 전진" 매핑이 사용자 체감과 반대였다. `HandInputResolver.twoHandState`를 거울상으로 뒤집었다: `distance >= spreadFull`(멀리 벌림) → `.reverse`, 그 안쪽은 가까울수록 `.forwardFull`(≤ `reverseThreshold`) → `.forwardHalf`(≤ `spreadHalf`) → `.waiting` 순서. 히스테리시스도 방향에 맞춰 거울상으로 다시 짰다(낮은 쪽 경계+마진으로 "전진 단계에서 빠져나가기 어렵게").
- **영향**: 손 사이 거리와 드라이브 상태의 관계가 정확히 반대가 됐다. `KartCoreTests`의 관련 테스트 이름과 기대값을 전부 새 방향에 맞게 다시 썼다(`bothHandsVeryCloseIsForwardFull`, `bothHandsSlightlySpreadIsForwardHalf`, `bothHandsModerateSpreadIsWaiting`, `bothHandsWideSpreadIsReverse`, `hysteresisKeepsForwardFullUntilGrowingAboveMargin`).
- **영향받는 절**: 결정 27번, `KartCoreTests`

## 29. 카트 정면 보정을 고정 180도 대신 "front" 이름 자식 엔티티로 자동 계산

- **날짜**: 2026-10-10
- **배경**: 결정 27번에서는 모든 카트가 정면을 로컬 +Z로 export했다고 가정하고 고정 180도 보정을 썼다. 사용자가 Reality Composer Pro 기준 계층을 직접 확인해 보니, 각 카트 USDZ 안에 차량 앞을 가리키는 **"front"라는 이름의 자식 엔티티**가 실제로 들어 있다고 알려줬다 — 이걸 읽으면 추측(180도) 대신 정확한 보정을 모델마다 자동으로 계산할 수 있다.
- **수정**: `ImmersiveBoxView`에 `findDescendant(in:nameContains:)`(이름에 "front"가 들어간 자식을 재귀 탐색)와 `frontCorrectionAngle(for:fallbackDegrees:)`를 추가했다. "front" 자식을 찾으면 그 위치(`position(relativeTo: entity)`)가 가리키는 방향을 로컬 -Z(우리 쪽 "전진" 기준)로 맞추는 Y축 회전을 계산해서 쓴다(공식: `φ = π/2 + atan2(nose.z, nose.x)`, `R(φ)` 적용 시 `(nose.x,0,nose.z) → (0,0,-1)`이 되도록 유도). "front" 자식이 없거나 위치가 원점과 거의 같으면 `KartModel.modelForwardCorrectionDegrees`(기본 180도)로 돌아간다. 어느 경로를 탔는지, 계산된 각도가 몇 도인지 `DEBUG-FRONT` 로그로 남긴다.
- **영향받는 절**: 결정 27번(고정 180도 보정을 대체), `ImmersiveBoxView.loadKart()`

## 30. 전진/후진 페달을 "거리 → 연속 가속" 모델로 전면 재설계 + 후진 중 회전 수정

- **날짜**: 2026-10-10
- **요구사항**: "양손 핀치 거리가 40cm 이하면 벌릴수록 가속하며 후진, 40cm 초과면 좁힐수록 가속하며 전진"으로 바꾸고, 움직이는 중(전진·후진 모두)에도 좌/우 회전이 가능해야 한다.
- **결정**: 결정 28번까지 썼던 "단계별 상태(정지/대기/절반전진/전체전진/후진) + 히스테리시스" 방식을 버리고, 손 사이 거리를 하나의 연속 값으로 바로 매핑하는 방식으로 바꿨다. `DriveState`의 `forwardHalf`/`forwardFull`/`reverse`를 전부 지우고 `case pedal(Float)`(-1 최대 후진 ~ 0 중립 ~ +1 최대 전진) 하나로 합쳤다. `HandInputResolver.pedalValue(for:)`가 거리를 이 값으로 바꾼다: `pivotDistance`(40cm) 이하(좁음)면 음수, 초과(넓음)면 양수이고, **각 구간에서 기준점에 가까워질수록 그 방향으로 더 세진다**(좁은 쪽은 벌릴수록, 넓은 쪽은 좁힐수록 → 최댓값은 둘 다 40cm 바로 옆에서 나온다). 정확히 40cm에서 전진/후진이 순간적으로 뒤집히지 않도록 `pivotDeadband`(±2cm)는 중립으로 둔다. 상태가 더 이상 이력(hysteresis)에 의존하지 않아 `HandInputResolver`의 `lastDriveState`도 함께 지웠다.
- **후진 중 회전 버그 수정**: `KartMotionState.advancing()`의 회전 조건이 `next.speed >= tuning.minTurnSpeed || next.speed == 0`였는데, 후진 중(속도가 음수)이면 이 조건이 항상 거짓이 되어 회전이 전혀 안 먹혔다. `abs(next.speed) >= tuning.minTurnSpeed`로 바꿔 전진/후진 어느 쪽이든 충분한 속력이 있으면 회전이 걸리게 했다.
- **덧붙여 단순화**: 결정 27번에서 넣었던 "`.reverse`는 항상 `brakeDecel` 비율로 접근" 특례도 같이 지웠다 — 연속 페달 값에서는 원래의 일반 규칙(목표보다 빠르면 감속, 느리면 가속)이 전진/후진 모두에 그대로 들어맞는다.
- **영향받는 파일**: `DriveState`, `InputTuning`(`spreadHalf`/`spreadFull`/`spreadHysteresis`/`reverseThreshold` → `pivotDistance`/`forwardSpan`/`pivotDeadband`), `KartMotionState`, `HandInputResolver`, `KartCoreTests`(관련 테스트 전부 새로 작성)

## 31. 방향 정정: "40cm 이하=후진/초과=전진"이 아니라 "핀치인=전진/핀치아웃=후진"

- **날짜**: 2026-10-10
- **배경**: 결정 30번은 "40센치 이하인 경우 벌릴수록 후진, 초과인 경우 좁힐수록 전진"이라는 문장을 "각 구간 안에서 기준점에 가까워질수록 세진다(최댓값이 40cm 양옆에 붙어 있고, 양쪽 끝(거리 0, 혹은 멀리)에선 중립으로 돌아간다)"는 구조로 읽고 구현했다. 사용자가 "핀치in할수록 전진, 핀치out할수록 후진"이라고 더 명확하게 정정해 줘서, 실제로는 훨씬 단순한 — 그리고 더 직관적인 — "한쪽 끝(손을 완전히 모음)에서 최대 전진, 반대쪽 끝(최대로 벌림)에서 최대 후진, 가운데(40cm)가 중립"인 단조 증가 모델이 맞다는 걸 확인했다.
- **수정**: `HandInputResolver.pedalValue(for:)`를 다시 썼다. `distance <= pivotDistance - deadband`(핀치인 쪽)는 거리가 **작을수록**(0에 가까울수록) 페달이 `+1`에 가까워지고(거리 0에서 정확히 +1), `distance >= pivotDistance + deadband`(핀치아웃 쪽)는 거리가 **클수록** `-1`에 가까워진다(`pivotDistance + reverseSpan`에서 정확히 -1, 그 뒤로는 클램프). `InputTuning.forwardSpan`은 더 이상 쓰지 않아 `reverseSpan`으로 이름을 바꿨다(이제 전진 쪽은 자연스러운 하한인 거리 0을 그대로 쓰고, 후진 쪽만 별도 폭이 필요하다).
- **영향받는 절**: 결정 30번(모델 구조는 유지, 거리↔값 매핑 공식만 교체), `KartCoreTests`(관련 테스트 전부 새 방향에 맞게 재작성 — 특히 "멀리 벌어지면 중립으로 클램프"였던 테스트가 "멀리 벌어지면 최대 후진으로 클램프"로 바뀜)

## 32. 카트 모델이 항상 뒤로 달리는 것처럼 보이던 문제 — "front" 마커 보정 방향이 반대였음

- **날짜**: 2026-10-10
- **증상**: "좁히든 벌리든 계속 한쪽으로만 이동 중"이라는 리포트. 실기기에서 방금 켠 세션의 `DEBUG-MOTION` 로그를 직접 확인한 결과, `drive=pedal(0.49)`일 때는 `speed`가 양수, `drive=pedal(-1.0)`일 때는 음수로 정확히 갈렸고 `pos`의 변화 방향도 그에 맞게 반대로 움직였다 — 즉 핀치인/아웃 → 전진/후진 페달 로직(결정 31번)과 실제 위치 이동은 이미 정상이었다. 진짜 원인은 사용자가 바로 짚어준 대로 **카트 3D 모델 자체의 앞/뒤 보정 방향**이었다: 위치는 정상적으로 전진·후진하는데, 모델이 그 방향에 대해 항상 뒤집힌 채로 보여서 "차가 계속 뒤로만 달리는 것처럼" 보인 것.
- **원인**: 결정 29번에서 만든 `frontCorrectionAngle`은 "front" 마커의 위치가 로컬 **-Z**를 향하도록 보정값을 계산했다. 실기기 로그(`DEBUG-FRONT`)를 보면 이 로스터의 `front_aero` 마커는 로컬 **+Z**(위치 `(0, 0.24, 1.41)`)에 있어서 180도 보정이 적용됐는데, 사용자가 실기기로 눈으로 확인한 결과 이게 오히려 반대였다 — 즉 이 모델은 애초에 **+Z가 정방향**이라, 180도를 돌리면 오히려 뒤집히는 것이었다(아마 이 로스터를 만든 툴이 RealityKit/ARKit과 전후 축 관례가 반대인 듯).
- **수정**: `frontCorrectionAngle`의 목표를 `(0,0,-1)`에서 `(0,0,+1)`로 뒤집었다 — 공식을 `φ = π/2 + atan2(nose.z, nose.x)`에서 `φ = atan2(nose.z, nose.x) - π/2`로 바꿨다(모든 입력에 대해 이전 값 + 180도와 동일). `KartModel.modelForwardCorrectionDegrees`(마커를 못 찾았을 때만 쓰는 fallback)도 같은 이유로 180 → 0으로 바꿨다.
- **영향받는 절**: 결정 29번(목표 축을 대체), `KartCatalog`, `ImmersiveBoxView.frontCorrectionAngle`

## 33. 진짜 원인: 핀치 손 좌표가 미터가 아니었다 — `location3D`를 scene 좌표로 변환 안 함

- **날짜**: 2026-10-10
- **증상**: "핀치 벌리고 좁히는 것에 반응이 안 보이고, 양손 핀치 시 항상 전진(실제로는 한쪽 극단) 중"이라는 리포트. 방금 켠 실기기 세션의 `DEBUG-MOTION` 로그를 보니 `drive=pedal(...)` 값이 100줄 넘게 거의 전부 `pedal(-1.0)`으로 고정돼 있었고(`pedal(1.0)`은 단 1번), 손을 벌리거나 좁혀도 값이 거의 안 바뀌었다 — 즉 손 사이 거리가 거의 항상 클램프 범위(`pivotDistance + reverseSpan` = 0.82m) 밖에 있다는 뜻이었다.
- **원인**: `ingest()`가 `event.location3D`를 **변환 없이** 그대로 썼다. `SpatialEventGesture().targetedToEntity(inputCatcher)`로 받는 이벤트의 `location3D`는 `inputCatcher`의 로컬 좌표계 기준이라 미터 단위가 아니다(실측 로그에서 좌표 값이 수백 단위로 나온 이유). `InputTuning`의 모든 거리 임계값(`pivotDistance` 40cm 등)은 미터 기준으로 잡아 둔 거라, 손 사이 거리가 늘 기준값보다 압도적으로 커서 항상 한쪽 극단(클램프된 -1.0 혹은 +1.0)으로 튀었다 — "벌리고 좁히는 데 반응이 없다"는 바로 이 클램프 상태에서 미세하게 움직이는 걸 가리킨 것이었다. Apple 공식 샘플("Petite Asteroids")도 `event.convert(value.location3D, from: .local, to: .scene)`로 반드시 변환해서 쓰는데, 우리는 이 변환을 빠뜨렸다.
- **수정**: `driveGesture`의 `onChanged`/`onEnded` 클로저가 `EntityTargetValue<SpatialEventGesture.Value>` 전체(`value`)를 `ingest()`에 넘기도록 바꾸고(기존엔 `value.gestureValue`만 넘겨서 변환에 필요한 `value`를 잃어버렸다), `ingest()` 안에서 `value.convert(event.location3D, from: .local, to: .scene)`로 scene(월드, 미터) 좌표로 변환한 뒤 거리 계산에 쓴다.
- **참고**: 좌표 단위가 이제 정상적인 미터로 바뀌었으니, `pivotDistance`(40cm)·`reverseSpan`(40cm) 같은 수치가 실제 손 동작 범위에 맞는지는 다시 실기기로 확인이 필요하다 — 느낌이 이상하면(예: 너무 쉽게 꽉 차거나 거의 안 움직이거나) 바로 알려주면 값을 조정한다.
- **영향받는 절**: `ImmersiveBoxView.ingest()`/`driveGesture`, 결정 20·21·24번(전부 이 변환 누락 위에서 작업했던 것들), `InputTuning`(수치 재검토 필요)

## 34. 디자인 결정 20·21번에 대한 테크 반영 + 박스 치수 확정(20-10 답변)

- **날짜**: 2026-10-10
- **배경**: `main` 브랜치에 디자이너가 결정 20·21번(메뉴 피드백 답변, 바닐라 텍스처 금지)을 올리고, "merge 후 클로드에게 갱신된 문서로 수정시켜보도록 하겠습니다"라는 메모를 남겼다. 아래는 그걸 보고 바로 반영 가능한 항목들.
- **반영**:
  - **20-2(색상 스와치)**: `ColorSwatch` 크기 28→40pt, 간격 10→14pt로 확대. `KartCatalog.standardColors` 정렬을 알파벳 순 → 색상환 순(빨강→주황→...→마젠타→핑크, 그 다음 갈색·무채색)으로 재배열.
  - **20-7·20-8(카트 로스터)**: `KartCatalog.karts`에서 `mms` 제거(5종 확정). 더 이상 코드에서 참조하지 않는 `Resources/Karts/mms.usdz`(29MB)도 같이 삭제해 실제로 용량 문제를 해소했다 — `KartCatalog`에서만 빼고 파일을 남겨두면 `PBXFileSystemSynchronizedRootGroup`이 폴더 전체를 그대로 번들에 넣어서 용량이 안 줄어든다.
  - **20-9(360도 회전)**: 메뉴 `KartCard`를 SF Symbols placeholder 대신 `Model3D(named:)`로 실제 USDZ를 띄우고, `DragGesture` + `.rotation3DEffect(axis: (0,1,0))`로 드래그 회전을 추가했다(Apple 공식 튜토리얼 "Create 3D models in the Shared Space" 패턴). 이 작업이 20-1(카트 아이콘을 실제 모델/썸네일로)도 같이 해결한다 — 정적 썸네일 대신 실제로 돌려볼 수 있는 라이브 3D 프리뷰.
  - **20-10(박스 치수)**: 디자이너가 실기기가 없어 테크에 위임한 항목. 지금까지 여러 차례 실기기 테스트로 확인한 `boxSize = [0.7, 0.4, 0.7]`m을 그대로 확정한다. PRD 원안(1.4×0.6×1.1m)보다 작지만, 책상 위 디오라마로 보면서 손이 핀치 제스처로 편하게 닿는 범위를 실기기 기준으로 맞춘 값이라 이쪽을 유지한다.
- **보류(자산 전달 대기)**: 20-1 일부(HUD/미니맵용 픽셀 실루엣), 20-3·20-5(Galmuri 폰트 파일), 20-6(엔진음 루프 사운드 파일), 20-11~13(RetireX 팔레트/`Design/style-guide.md`, 리소스 파일명 규칙), 21(바닐라 텍스처 교체) — 전부 디자이너가 전달할 파일/문서가 필요해서 리포지토리에 자료가 도착하면 바로 연결한다.
- **영향받는 절**: `KartCatalog.swift`, `ContentView.swift`, `README.md`(디자인 피드백 반영 결과 추가), `Docs/TechTask.md`(열린 질문 정리), 디자인 결정 20·21번

## 20. [디자인] 디자인 결정 묶음 (메뉴 피드백·디자인 PRD 열린 질문 답변)

- **날짜**: 2026-10-10
- **결정자**: 디자인
- **배경**: README "디자인 피드백 2026-10-10" 4건, 디자인 PRD 15장 열린 질문, `Docs/TechTask.md` 열린 질문 중 디자인 관련 항목에 대한 답변.

| # | 항목 | 결정 |
| --- | --- | --- |
| 20-1 | 카트 아이콘 | 메뉴 카트 카드는 **3D 렌더 썸네일**. HUD·미니맵 등 작은 표시에는 **픽셀 실루엣**을 쓴다 |
| 20-2 | 색상 스와치 | 원 크기와 간격이 너무 작으므로 **키운다**. 배열은 **색상 순서(색상환 순)**로 정렬한다 |
| 20-3 | 타이포 | **제목에만 픽셀 폰트**, 본문·숫자·라벨·버튼은 시스템 폰트 (디자인 PRD 3장 그대로 확정) |
| 20-4 | 카드·버튼 재질 | 당분간 visionOS **글래스 재질 유지**. 이후 UI 작업 중 바뀔 수 있음 |
| 20-5 | 픽셀 폰트 | **Galmuri** 확정 |
| 20-6 | 엔진음 루프 | **1차에 포함**. 소리 파일과 설명은 RetireX Online 쪽(디자인)에서 준비해 `Assets/sfx/`에 넣는다 (디자인 PRD 10장 "엔진음 루프는 1차 범위 밖"을 뒤집음) |
| 20-7 | 카트 로스터 | `arcrix`, `bogubkart`, `gospel`, `razr`, `sirius` **5종**을 최종 로스터로 쓴다 |
| 20-8 | `mms` | **제외**. 카트가 아니라 일반 자동차 모델이므로 로스터에 맞지 않음 (용량 30MB 문제도 함께 해소) |
| 20-9 | 메뉴 카트 360° 회전 | **넣는다**. 드래그로 카트를 돌려 볼 수 있게 |
| 20-10 | 박스 디오라마 치수 | 디자이너가 Vision Pro 실기기가 없어 판단 불가 → **테크에 위임**. 실기기 기준으로 정하고 결과만 공유 요청 |
| 20-11 | 팔레트 기준 | 디자인 PRD 3장 12색 팔레트 대신 **RetireX 프로젝트의 색 체계**를 기준으로 쓴다. `Design/style-guide.md`에 반영 예정 |
| 20-12 | RetireX 리소스 사용 | 디자이너 본인 프로젝트이므로 **사용 가능**. 단 아래 21번 예외 |
| 20-13 | 파일명 | RetireX에서 가져오는 리소스도 **PRD 이름 규칙으로 바꿔서** 넣는다 (`countdownTick.wav`, `tile_straight` 등) |

- **보류**: 앱 이름(결정 7번)은 추후 테크·디자인이 함께 상의한다.
- **영향받는 절**: 디자인 PRD 3·4·10·15장, 테크 PRD 10장(효과음 — 엔진음 루프 추가), `Docs/TechTask.md` 열린 질문, `KartSimulator/Models/KartCatalog.swift`(mms 제외는 테크가 반영)

## 21. [디자인] 마인크래프트 바닐라 텍스처 사용 금지

- **날짜**: 2026-10-10
- **결정자**: 디자인
- **결정**: RetireX 리소스에 섞여 있는 마인크래프트 바닐라(Mojang) 텍스처·사운드는 이 앱에 쓰지 않는다. 발견되면 디자인 쪽에서 16×16 **임시 대체 텍스처**를 새로 그려 넣고, 이후 정식 텍스처로 교체한다.
- **이유**: Mojang EULA상 바닐라 리소스를 별도 앱에 재배포할 수 없다.
- **영향**: 트랙 타일 등 복셀 텍스처. 임시 텍스처는 PRD 파일명을 그대로 써서 교체 시 코드 변경이 없게 한다.

## 35. [테크] 디자인 자산 1차 드롭 반영: 제목 폰트·엔진음/효과음·HUD·트랙 팔레트·팀 표

- **날짜**: 2026-10-11
- **배경**: `main`에 `design` 브랜치가 머지되며(PR #6, 결정 34번 "보류" 목록) Galmuri 폰트, 효과음 12종(`Assets/sfx/`, `ENGINE.md` 재생 규칙 포함), 대체 텍스처 15종, `Design/style-guide.md`가 한꺼번에 도착했다. `origin/main`을 `Dev`로 머지해 받아왔다(머지 중 이 파일에 "## 34. 디자인 결정 묶음"으로 잘못 붙은 섹션을 "## 20. [디자인]"으로 바로잡음 — 위 안내문과 20·21번 항목 참고).
- **1. 제목 폰트(20-3·20-5)**: `Galmuri11-Bold.ttf`/`Galmuri14.ttf`를 `KartSimulator/Resources/Fonts/`에 복사하고 `AddInfoPlist` 도구로 `UIAppFonts`를 등록했다(`GENERATE_INFOPLIST_FILE=YES`와 병합되는 부분 `KartSimulator/Info.plist`가 새로 생겼다 — 배열 값은 `INFOPLIST_KEY_*` 빌드 설정으로 못 넣는다). `ContentView`의 "핀치 카트" 제목에 `Font.custom("Galmuri11-Bold", size: 40, relativeTo: .largeTitle)` 적용(TTF `name` 테이블의 PostScript 이름을 직접 읽어서 확인). 본문·HUD는 시스템 폰트 그대로(결정 20-3).
- **2. 엔진음 + 효과음 7종(20-6)**: `Assets/sfx/ENGINE.md`의 상태 기계·재생 규칙을 거의 그대로 옮겼다. `KartCore/EngineSoundMachine.swift`(순수 값 타입, RealityKit 의존 없음 — 문서 원문은 `forwardHalf`/`forwardFull` 2단계 `DriveState` 기준이었는데, 지금은 연속 페달(`DriveState.pedal(Float)`)이라 크기(`abs(value)`, 방향 무관)를 그대로 목표 속도비로 쓰도록만 바꿨다) + `RealityKit/EngineAudioPlayer.swift`(`AudioFileResource`/`AudioPlaybackController` 어댑터) + `RealityKit/SFXPlayer.swift`(한 발성 7종: checkpoint/countdownTick/finish/go/lapComplete/respawn/wallBump). `ImmersiveBoxView`에 연결: 트랙 로드 시 카운트다운(틱 3회+go, `engineIgnition`과 병렬) 시작, 매 프레임 `tickMotion`에서 엔진 상태 기계 갱신, 체크포인트/랩/완주/리스폰 시점에 각 효과음 재생. `wallBump`는 벽 콜리전이 아직 없어(M3) 로드만 해 두고 트리거는 없음. `KartCoreTests`에 상태 기계 핵심 전환 5개 추가.
- **3. HUD/트랙 팔레트(20-11)**: `Design/style-guide.md` 1장 색표를 `Utilities/StylePalette.swift`에 그대로 옮기고(트랙 7색 + UI 11색 + 미니맵 3색), `ImmersiveBoxView`의 트랙 바닥(`road`)·경로점(`edgeLine`)·출발점(`mmFinish`)과 HUD 글자(`uiInk`)·경고(`uiWarn`)에 적용했다. 카드·버튼 배경은 글래스 재질 유지(결정 20-4, 안 건드림). `KartCatalog.standardColors`도 스타일 가이드 1-3장 "카트 도색 17색" 표의 정확한 hex·순서로 교체했다(이전엔 임의로 고른 hex였다).
- **4. README 팀 표**: Tech/Design 담당을 각각 `kimminung`/`iMasterProX` GitHub 프로필 링크로 교체.
- **참고**: 스타일 가이드 1-3장은 색상 스와치 지름/간격을 28pt/10pt로 적어 두었는데, 이는 결정 20-2(실기기 확인 후 "너무 작다"는 피드백)로 이미 40pt/14pt로 키운 값과 다르다. 오늘은 "색"만 교체 대상이라 크기는 40pt/14pt를 유지했다 — 필요하면 다시 논의.
- **영향받는 절**: `ContentView.swift`, `KartCatalog.swift`, `ImmersiveBoxView.swift`, `KartCore/EngineSoundMachine.swift`(신규), `RealityKit/EngineAudioPlayer.swift`·`SFXPlayer.swift`(신규), `Utilities/StylePalette.swift`(신규), `Utilities/Color+Hex.swift`(`UIColor(hex:)` 추가), `README.md`, `KartCoreTests`, 결정 34번(보류 목록 대부분 해소)

## 36. [디자인] 새 조작 방식에 맞춘 온보딩·HUD 개정, 카트 카드 표시, 스와치 크기, 타일 전달 확인

- **날짜**: 2026-10-11
- **결정자**: 디자인
- **1. 온보딩·HUD를 연속 페달 조작으로 개정** (테크 결정 30·31 반영)
  - 온보딩 그림을 5장으로 바꿨다: `gesture_01_forward`(양손을 모을수록 전진), `gesture_02_reverse`(벌릴수록 후진, 새로 추가), `gesture_03_left`, `gesture_04_right`, `gesture_05_stop`. 예전 `gesture_02_left`·`gesture_03_right`·`gesture_04_stop`은 지웠다.
  - HUD 핀치 상태는 `stopped`·중립(`waiting`/`pedal(0)`)·전진(`pedal(+)`)·후진(`pedal(-)`)·좌·우 6상태와 세로 **페달 게이지**로 보여 준다. 전진은 `ui-cyan` ↑, 후진은 `ui-magenta` ↓로 색과 모양을 함께 구분한다(디자인 PRD 7장).
  - 아이콘: `arrow_reverse`, `pinch_in` 추가, `arrow_forward_full` 삭제. `ui-magenta`를 후진 전용 색으로 정했다(스타일 가이드 1-2).
  - 목업 `02_howto`, `05_racing`을 다시 그렸다.
- **2. 메뉴 카트 카드**: 테크 결정 34의 라이브 3D 모델 카드를 실기기 영상으로 확인했다. 기본은 **3D 렌더 썸네일을 작게** 보여 주고, **시선 포커스·호버일 때만 크게(약 1.4배) 확대**하면서 그때만 라이브 3D 모델과 360° 드래그 회전을 쓴다. 상세 규칙은 디자인 PRD 8장 "카트 선택 카드".
- **3. 색상 스와치 크기**: 테크가 실기기에 맞춰 키운 40 pt / 간격 14 pt를 정식 값으로 한다. 스타일 가이드 1-3의 28 pt / 10 pt를 고쳤다.
- **4. 트랙 타일 전달 확인**: 타일 4종은 이미 `main`에 있다 — 원본 `Assets/blockbench/tiles/tile_{straight,curve,start,grass}.bbmodel` + `tiles.png`, 내보내기 `Assets/export/glb/tile_*.glb`, 미리보기 `Design/reference/tiles_preview.png`·`tiles_preview_track01.png`. 디자인 PRD 12장대로 glb → USDZ 변환은 테크 몫이다. `Docs/TechTask.md` M3 "트랙 타일 4종 에셋 확보"와 결정 21 보류 항목은 이 파일들로 진행하면 된다.
- **영향받는 절**: 디자인 PRD 1·7·8·9·12·15장, `Design/style-guide.md` 1-2·1-3·3장, 테크 `HandInputResolver`/HUD(`RaceHUDOverlay`) 표시, `ContentView`의 `KartCard`

## 37. [테크] 결정 36 수용: 트랙 타일 3D 실제 배치, 페달 게이지 HUD, 카트 카드 호버 전환

- **날짜**: 2026-10-11
- **배경**: `design` 브랜치의 새 커밋(324cf10, 65af7b4)을 `Dev`로 머지해 결정 36번(온보딩·HUD 개정, 카트 카드, 스와치, 타일 전달)을 받았다. 충돌 없이 머지됐다(`git merge-base --is-ancestor`로 사전 확인).
- **1. 타일 glb → USDZ 변환(36-4)**: 이 Mac의 Model I/O는 `.glb`/`.gltf`를 import 못 하고 `.usdz` export도 못 해서(`MDLAsset.canImportFileExtension`/`canExportFileExtension` 모두 false), 헤드리스 **Blender 5.2.2**(`--background --python`)로 변환했다 — `import_scene.gltf` → `wm.usd_export(export_textures_mode="NEW", convert_orientation=True, export_global_forward_selection="NEGATIVE_Z", export_global_up_selection="Y")`. `export_textures_mode="PRESERVE"`(기본값 아님, 처음 시도)는 임베드된 텍스처를 외부 상대경로로만 참조해서 깨졌다 — `"NEW"`로 바꿔 텍스처를 새로 풀어서 같이 묶었다(원본 `tiles.png`와 바이트 동일 확인). 변환 결과(Y-up, 바닥 Y≈0, 4×4m)는 별도 Model I/O 스크립트로 검증했다. `Assets/export/glb/tile_*.glb` → `KartSimulator/Resources/Tiles/tile_{straight,curve,start,grass}.usdz`. 변환 스크립트는 `Tools/glb2usdz.py`로 커밋해 다음 에셋 드롭에도 재사용한다.
- **2. 트랙 타일 실제 3D 배치**: `RealityKit/TrackTileLibrary.swift`(타일 템플릿 캐시 + clone)를 추가하고, `ImmersiveBoxView`의 점열 placeholder `buildTrackVisual`을 지우고 `buildTrackTiles`/`placeTile`로 교체했다. `tiles` 배열에 있는 칸은 해당 타입 타일을, 없는 칸은 전부 잔디로 채운다 — 단 잔디는 `grid.cols`×`grid.rows` 전체가 아니라 **`tiles`의 실제 col/row 바운딩 사각형**만 채운다(전체를 채우면 `trackDisplayScale`이 경로 바운딩 박스 기준이라 0.7m 박스를 넘친다). `gen_track.py`의 타일 중심 공식(`col*tileSize+tileSize/2`, `-(row*tileSize+tileSize/2)`)을 그대로 따랐다.
- **실기기 확인 필요**: 타일 `rot`은 `gen_track.py`가 시계방향(컴퍼스) 각도로 기록하는데, RealityKit의 Y축 회전(`simd_quatf(angle:axis:[0,1,0])`)은 양수가 반시계 방향이라 부호를 뒤집어(`-Float(tile.rot)`) 적용했다. 인접 타일 노면이 실제로 이어지는지는 실기기에서만 확인 가능 — 안 맞으면 부호를 되돌린다. 벽 콜리전은 아직 없어서(타일은 보이지만 뚫고 지나감) 별도 작업으로 남겨 둔다.
- **3. HUD 페달 게이지(36-1)**: `RaceHUDOverlay`에 `PinchStatusView`/`PedalGaugeBar`를 추가해 양손 점 + 중앙 방향 아이콘 + 세로 게이지(전진 `ui-cyan` ↑ / 후진 `ui-magenta` ↓)를 그린다. 기존 `RaceHUDState.drive`/`left`/`right` 필드를 그대로 재사용했다.
- **4. 카트 카드 호버 전환(36-2)**: `ContentView`의 `KartCard`를 다시 썼다. 기본은 디자이너가 전달한 정적 썸네일(`Design/karts/kart_<id>_thumb.png` → `Resources/KartThumbnails/`에 복사, `Image(_:)` 이름 조회가 안 되는 낱장 PNG라 `Bundle.main.url` + `UIImage`/`NSImage`로 로드)을, `.onHover`로 포커스 상태일 때만 1.4배로 키우고 그때만 `Model3D` 라이브 모델 + 드래그 회전으로 바꾼다.
- **영향받는 절**: `Docs/TechTask.md` M1·M3·M5, `ImmersiveBoxView.swift`, `TrackTileLibrary.swift`(신규), `ContentView.swift`, `Tools/glb2usdz.py`(신규), `KartSimulator/Resources/Tiles/`·`KartSimulator/Resources/KartThumbnails/`(신규 리소스)
- **추가 보완(같은 날)**: GitHub PR #8(`gh` 미인증이라 `git fetch origin refs/pull/8/head`로 직접 받아 확인 — 내용은 324cf10·65af7b4와 동일해 이미 Dev에 들어와 있었음)의 디자인 PRD 7장 표와 코드를 대조해서 빠진 2곳을 고쳤다: (1) `waiting` 상태(거리 계산 전 과도기)에서 게이지가 아예 안 보이던 것을 `pedal(0)`과 같은 중립 줄로 묶어 항상 보이게 함, (2) 게이지 아래 "전진 N%"/"후진 N%"/"중립" 글자 라벨이 없던 것을 추가.

## 38. [테크] 이슈 #9·#12 잔여 항목 반영: 벽 콜리전 + wallBump, 조작법 화면

- **날짜**: 2026-10-11
- **배경**: PR #8을 main에 머지한 뒤, 그 본문이 가리키는 GitHub 이슈 #9~#12(트랙 타일, HUD, 카트 카드, 조작법)를 하나씩 코드와 대조했다. #10·#11은 결정 37번으로 이미 끝나 있었고, #9는 "벽 콜리전 연결 + wallBump 트리거" 항목이, #12는 전체가 빠져 있었다.
- **1. 벽 콜리전 + `wallBump`(이슈 #9)**: 타일 메시에 `CollisionComponent`를 붙여 레이캐스트하는 대신, 매 프레임 이미 계산하던 중심선 거리 계산을 재사용했다. `TrackPath.closestSegment`가 이제 중심선 위 투영점도 같이 반환하도록 바꾸고(`KartCoreTests`의 두 테스트는 named tuple이라 그대로 통과), `ImmersiveBoxView.tickMotion`에서 `distanceFromCenterline > tileSize/2`(타일 가장자리)면 투영점 방향으로 그 자리에 되밀어 넣는다. 벽에 처음 닿는 프레임에만 `wallBump`를 재생(`wasAgainstWall` 플래그로 중복 재생 방지). **알려진 단순화**: 커브 타일 안쪽 모서리에는 실제 벽이 없는데(이슈 #9 본문) 이 모델은 좌우를 구분하지 않아 양쪽을 다 막는다 — 실기기에서 커브 안쪽을 못 파고들어 어색하면 다시 손봐야 한다.
- **2. 조작법 화면(이슈 #12)**: `Design/onboarding/gesture_0{1-5}.svg`(모두 단순 `<rect>`만 있어 Xcode 벡터 에셋으로 바로 수입 가능했다)를 `Assets.xcassets/Onboarding/*.imageset`(`preserves-vector-representation`)으로 추가하고, `ContentView`에 `OnboardingView`(5장 그림 + 설명 + "양손 사이 약 40 cm에서는 제자리(중립)" 안내 + "알겠어요")를 시트로 붙였다. 첫 실행 시 `@AppStorage("hasSeenOnboarding")`로 자동 표시, "조작법" 버튼으로 다시 볼 수 있다. 디자인 PRD 8장의 전체 "메뉴 4화면"(시작/대기/카운트다운/결과) 리디자인은 범위 밖이고, 조작법 한 장만 반영했다.
- **반영 안 함(검토 후 판단)**: 이슈 #9의 "풍경 텍스처가 필요하면 `Design/textures/tex_*.png` 사용"은 조건부 항목이다. 잔디 타일(`tile_grass.usdz`)이 이미 원본 `tiles.png` 텍스처를 그대로 갖고 있어 트랙 바운딩 박스 안쪽은 전부 덮이고, 그 바깥의 박스 바닥판은 결정 35번에서 이미 스타일 가이드 색(`StylePalette.road`)으로 의도적으로 깔아 둔 부분이라 추가 텍스처가 필요 없다고 판단했다.
- **확인**: 두 변경 모두 visionOS 시뮬레이터 destination으로 전체 빌드 통과(`BuildProject`), `KartCoreTests` 37개 중 35개 통과 — 실패한 5개(`EngineSoundMachineTests`, 엔진 사운드 상태 전환)는 오늘 건드린 파일과 무관한 기존 결함으로 별도 기록. 실기기(진짜 Vision Pro)는 사용자 지시에 따라 건드리지 않았다.
- **영향받는 절**: `Docs/TechTask.md` M3·M5, `KartCore/TrackPath.swift`(반환 튜플에 `projected` 추가), `ImmersiveBoxView.swift`, `ContentView.swift`, `Assets.xcassets/Onboarding/`(신규), GitHub 이슈 #9·#12, PR #14

## 39. [테크] 운전 모드 3종(디오라마·1인칭·3인칭) 도입 — Phase 1

- **날짜**: 2026-10-11
- **배경**: 1인칭 시뮬레이션이 어지러움증을 유발할 수 있어, 몰입도가 다른 선택지를 두기로 했다. 지금까지의 기본 모습(박스를 밖에서 보며 카트를 조종)을 **디오라마 모드**라는 이름으로 못박고, 그 옆에 **1인칭**(머리 방향으로 서서히 조향, 손은 가속만)과 **3인칭**(1인칭과 같은 시점이지만 조향은 이 프로젝트가 맨 처음 썼던 한손 핀치 좌/우회전 방식)을 추가했다. 디오라마 모드에는 박스 밖에서 카트를 직접 조종하는 새 조작법(양손 핀치 유지=전진, 핀치한 채로 벌리기=후진, 한쪽 손만 남으면 그 반대쪽으로 회전)을 넣었다.
- **기술 노트 — "아이트래킹" 정정**: visionOS는 서드파티 앱에 실제 눈동자 방향(raw gaze vector)을 주지 않는다(개인정보 보호). 이 프로젝트가 "시선"이라고 불러온 `worldTracking.queryDeviceAnchor` 값도 사실은 **헤드(기기) 방향**이다. 그래서 "아이트래킹으로 모드 전환"은 실제로는 **시스템 표준 시선+핀치 버튼 선택**(`ModeSwitchView`의 평범한 SwiftUI `Button` 3개, HUD attachment 안이라 시스템이 자동으로 호버+핀치 선택을 처리)으로 구현했다. 1인칭의 "시선 조향"도 정확히는 "머리 방향 조향"이다.
- **범위(Phase 1)**: 모드 전환 프레임워크 + 세 모드의 입력/조향 로직만 이번에 구현했다. 1인칭도 아직 디오라마와 같은 작은 박스 스케일로 시험한다 — 트랙을 실제 크기로 키우고 유저 머리 위치에 카트를 "고정"시키는 콕핏 기법(Phase 2)은 다음으로 미뤘다. 스트리밍/컬링(반경만 렌더링)은 트랙이 보통 16~64 타일이라 처음부터 만들지 않고, 실기기로 무거운지 먼저 재본 뒤에만 추가하기로 했다(과설계 방지).
- **구현**:
  - `ExperienceMode`(신규, `KartCore`): `.diorama`/`.firstPerson`/`.thirdPerson`.
  - `DriveState`에 `.headSteered(accelerating:)` 케이스 추가(기존 `.stopped`/`.waiting`/`.turnLeft`/`.turnRight`/`.pedal`는 그대로 유지 — 디오라마·3인칭이 계속 쓴다). `KartMotionState.advancing`에 `desiredHeading: Float? = nil` 파라미터를 추가해, `.headSteered`일 때만 머리 방향으로 최단 경로(±π 랩어라운드 처리)·`steerRateDegrees`(신규 튜닝값, 기본 120°/s)만큼씩 heading을 돌린다. 기존 손 회전 로직(`turnRateLow`/`turnRateHigh`/`minTurnSpeed`)은 그대로 둬서 디오라마·3인칭에 계속 쓴다.
  - `HandInputResolver.resolve(now:mode:)`가 모드별로 완전히 다르게 해석한다: 디오라마는 양손 핀치 시작 지점(순간 거리) 대비 **상대 드래그**로 전·후진을 가른다(`InputTuning.reverseDragDeadband`/`reverseDragSpan`로 절대 40cm 피벗을 대체) + 한손만 핀치=회전. 3인칭은 같은 손 모양이지만 양손 핀치면 거리와 무관하게 항상 `pedal(1.0)`(후진 없음). 1인칭은 한쪽이라도 핀치하면 `.headSteered(accelerating: true)`.
  - `ImmersiveBoxView`: 기존 디버그 전용 헤드 기즈모(`updateHeadDebugGizmo`)가 이제 `desiredHeading`(`atan2(-forward.x, -forward.z)`)도 같이 반환해서 1인칭 조향에 쓴다(`rootEntity`가 회전 없이 평행이동만 해서 씬 좌표축이 트랙 좌표축과 그대로 일치 — 별도 변환 불필요). HUD에 `ModeSwitchView`(모드 전환 버튼 3개) 추가, `PinchStatusView`에 `.headSteered` 아이콘 추가.
  - `ContentView`의 `OnboardingView`를 모드 선택 세그먼트로 바꿔 모드별 설명을 보여준다. 디오라마는 기존 SVG 그림(캡션만 새 제스처에 맞게 수정), 1인칭·3인칭은 디자인이 아직 전용 그림을 안 만들어서 SF Symbols로 자리만 잡아 뒀다.
- **확인**: visionOS 시뮬레이터로 전체 빌드 통과, `KartCoreTests` 45개 중 39개 통과(새로 쓴 디오라마/3인칭/1인칭 테스트 전부 포함) — 실패 5개는 전부 기존의 무관한 `EngineSoundMachineTests` 결함. 실기기는 건드리지 않았다.
- **영향받는 절**: `Docs/TechTask.md` M2, `KartCore/ExperienceMode.swift`(신규), `DriveState.swift`, `HandInputResolver.swift`, `InputTuning.swift`, `MotionTuning.swift`, `KartMotionState.swift`, `ImmersiveBoxView.swift`, `ContentView.swift`, `KartCoreTests`

## 40. [디자인] 운전 모드 3종 온보딩 그림 — 디오라마 캡션 개정, 1인칭 2장·3인칭 4장 신규

- **날짜**: 2026-10-11
- **결정자**: 디자인(요청·사양) — 실제 작성·커밋·머지는 테크 쪽 Claude가 `design` 브랜치에서 했다(PR #16, Issue #31 검수에서 정정). 1인칭 그림 2장과 3인칭 4장은 결정 47·49로 폐기됐다.
- **배경**: 테크 결정 39(운전 모드 3종, `Dev` 브랜치 — 이 PR 시점에는 아직 `main`에 없다)로 조작법 화면이 디오라마·1인칭·3인칭 세그먼트로 나뉘었는데, 그림은 디오라마용 5장뿐이라 테크가 1인칭·3인칭 칸에 SF Symbols로 자리만 잡아 둔 상태였다. 요청대로 디오라마 5장은 캡션 중심으로 손보고, 1인칭 2장·3인칭 4장을 새로 만들었다. 파일명은 테크가 제안한 이름 그대로다.
- **1. 디오라마 5장**
  - `gesture_01_forward`: 전진의 뜻이 "모을수록"에서 "핀치 시작 자리를 유지"로 바뀌어(결정 39의 상대 드래그) 안쪽 화살표를 지웠다. 손을 03~05와 같은 자리(x 8/136)로 옮기고, 두 핀치 점을 잇는 `ui-cyan` 점선(dash 4/6, 70 %)으로 "그 자리에 둔다"를 표현했다.
  - `gesture_02_reverse`: 그림 그대로(넓게 벌린 양손 + `ui-magenta` 바깥 화살표가 "핀치한 채로 벌리면"과 맞다). `gesture_03_left`·`04_right`·`05_stop`: 그림 변경 없음, 캡션만 테크 `OnboardingView`와 맞췄다.
- **2. 1인칭 2장**
  - `gesture_fp_01_steer`: 손 대신 **위에서 본 머리(헤드셋)**를 그렸다 — 머리 `ui-ink`, 바이저·스트랩 `black 0`(#252934), 바이저 앞선에 `ui-cyan` 유리선(어두운 배경에서도 앞뒤가 보이게), 바이저에서 머리 방향으로 나가는 `ui-cyan` 화살표. 머리 전체를 28° 돌리고 카트도 같은 각도로 돌린 뒤, 카트 코 앞에서 꺾이는 `ui-cyan` 점선 호(dash 8/6)로 "서서히"를 표현했다. 눈이 아니라 헤드셋인 이유는 결정 39 기술 노트(visionOS는 앱에 눈동자 방향을 안 준다 → 실제로는 머리 방향 조향).
  - `gesture_fp_02_throttle`: 왼손 핀치(활성) + `ui-cyan` ↑(가속), 오른손 펼침은 `ui-ink` 40 %(스타일 가이드 3장의 비활성 색) + 40 % ↓(감속), 카트는 전진 ↑. "한쪽 손이라도 핀치하면 가속, 떼면 감속"을 한 장에 담았다.
- **3. 3인칭 4장**
  - `gesture_tp_01_forward`: 양손 핀치 + 카트 전진 ↑ + 카트 오른쪽에 **후진 없음 배지**(`icon_arrow_reverse`를 `ui-magenta` 2배로 + `ui-ink` 사선). 디오라마 01과 달리 점선(자리 유지)도 간격 화살표도 없다 — 거리와 무관하게 항상 전진.
  - `gesture_tp_02_left`·`03_right`·`04_stop`: 디오라마 03·04·05와 같은 구성(같은 손 모양이 같은 뜻이라 일부러 같게). 테크가 모드별로 이름으로 연결하도록 파일만 따로 뒀다.
- **공통 규격**: 디자인 PRD 9장 그대로 — 240×240, 투명 배경, 1인칭 손등 시점, 핀치 점 `ui-cyan` r 7, 카트 48×48 위에서 본 픽셀 실루엣. 모든 장에서 손 자리를 x 8/136으로 통일해 장마다 바뀐 것만 눈에 들어오게 했다(예외: 02 넓게 벌림, fp 01 손 없음). 초판 PRD의 `hud-ink`/`accent-blue`는 RetireX 팔레트(결정 20-11)의 `ui-ink`/`ui-cyan`이다.
- **만든 방법**: `Design/tools/icons.mjs`를 확장했다(여러 색 픽셀 마스크용 `pix()`, 헤드셋 마스크 `HEAD_TOP`, `holdLine`/`noReverse`/`gentleArc`/`arrowV`). 모든 SVG가 여전히 `<rect>`·`<line>`·`<path>`·`<polygon>`과 `fill-opacity`만 쓰고(점선도 `stroke-dasharray` 대신 짧은 조각으로 그려서 Xcode SVG 수입기가 떨어뜨릴 요소가 없다), 결정 38에서 확인한 경로로 Xcode 벡터 에셋에 바로 들어간다. 미리보기 `Design/onboarding/_sheet.png`는 모드별 3줄로 다시 그렸다.
- **보류**: 목업 `Design/mockups/02_howto.png`는 모드 세그먼트가 생겨 화면 구성 자체가 바뀌어야 해서 이번엔 다시 그리지 않았다(PRD 8장 메뉴 4화면 리디자인 때 함께). HUD 24×24용 "머리 조향" 상태 아이콘은 테크가 `PinchStatusView`에 SF Symbol로 넣어 둔 상태라 요청이 오면 아이콘 세트에 추가한다.
- **테크에 넘기는 것**: `Assets.xcassets/Onboarding/`에 새 6장을 `preserves-vector-representation` imageset으로 추가하고, `ContentView.swift`의 `FirstPersonOnboardingContent`·`ThirdPersonOnboardingContent`에서 `SymbolInstructionCard`를 그림 카드로 교체. 캡션은 `_sheet.png`와 PRD 9장 표 그대로. 디오라마 중립 안내 문구도 "핀치를 시작한 자리에 두면 제자리(중립)"로.
- **영향받는 절**: 디자인 PRD 9·12·15장, `Design/onboarding/`(11장 + `_sheet.png`), `Design/tools/icons.mjs`, 테크 `ContentView.swift` `OnboardingView`

## 41. [테크] 디자인 결정 40 수용: 운전 모드 3종 온보딩 그림 11장 연결

- **날짜**: 2026-10-11
- **배경**: 결정 39에서 1인칭·3인칭 조작법 칸에 SF Symbols로 자리만 잡아 뒀던 것을, 디자인 PR #16(결정 40, `design` 브랜치)의 정식 그림으로 바꿨다. 결정 40은 `design` 브랜치에 있어 이 시점의 `Dev` `decisions.md`에는 아직 없다 — `main`에서 합쳐질 때 39·40·41 순서로 모인다.
- **반영**:
  - `Assets.xcassets/Onboarding/`에 `gesture_fp_01_steer`, `gesture_fp_02_throttle`, `gesture_tp_01_forward`~`gesture_tp_04_stop` 6개 imageset(`preserves-vector-representation`)을 추가하고, 그림이 바뀐 `gesture_01_forward.svg`(안쪽 화살표 → 핀치 점 잇는 점선)를 교체했다. 디자인이 `stroke-dasharray`·`opacity`를 피하고 `<rect>`·`<line>`·`<path>`·`<polygon>`·`fill-opacity`만 써서 Xcode SVG 수입에 특이사항 없음.
  - `ContentView`: 모드별로 따로 있던 `DioramaOnboardingContent`/`FirstPersonOnboardingContent`/`ThirdPersonOnboardingContent`와 `SymbolInstructionCard`를 하나의 `GestureInstruction.gestures(for:)` 표 + `GestureInstructionGrid`로 합쳤다. 캡션은 디자인 `_sheet.png`·PRD 9장 표와 글자 그대로 같다. 그림 아래 한 줄 안내(`footnote(for:)`)를 모드별로 두어, 디오라마의 옛 "양손 사이 약 40 cm = 중립" 문구를 "기준은 핀치를 시작한 순간의 손 간격" 설명으로 대체했다(결정 39의 상대 드래그).
- **확인**: visionOS 시뮬레이터 destination으로 빌드 통과. 코드 로직 변경은 없고 UI 자료만 바뀌어 `KartCoreTests`에는 영향 없음.
- **영향받는 절**: `Docs/TechTask.md` M5 조작법 항목, `ContentView.swift`, `Assets.xcassets/Onboarding/`, PR #15(Dev→main)에 커밋 추가

## 42. [테크] 카트 정면 보정 방향 되돌림: 결정 32는 오진이었다 — "front" 마커를 다시 로컬 -Z로

- **날짜**: 2026-10-11
- **증상**: 실기기에서 전진 입력을 주면 카트가 **뒷부분부터** 이동한다(이동 방향과 모델이 바라보는 방향이 반대). 모드 3종 Phase 1(결정 39) 이후 디오라마는 양손 핀치 즉시 `pedal(1.0)`이라 전진이 분명한데도 그랬다.
- **원인**: 주행 수학은 "모델 정면 = 로컬 -Z"를 전제로 한다(`forward = (-sin h, 0, -cos h)`와 `kartSlot.orientation = R_y(h)`가 그 전제에서만 일치, 결정 27번). 결정 29번의 `frontCorrectionAngle`은 "front" 마커를 -Z로 보내는 올바른 공식(`φ = π/2 + atan2(nose.z, nose.x)`)이었는데, 결정 32번에서 이를 +Z 목표로 뒤집었다. 그 시점에는 **손 좌표가 scene 좌표로 변환되지 않아**(결정 33번, 바로 다음 수정) 카트가 실제로 후진하고 있었고, 그걸 "모델이 뒤집혀 보인다"로 오인해 모델 쪽을 뒤집은 것이다. 결정 33으로 입력이 정상이 되자 이번엔 모델이 반대로 남았다. 이 로스터의 `front_aero` 마커는 로컬 +Z(0, 0.24, 1.41)에 있으므로 올바른 보정은 180도이고, 결정 32의 공식은 0도를 내고 있었다.
- **수정**:
  - 공식을 `KartCore/KartForwardCorrection.swift`(신규, 플랫폼 독립)로 빼고 결정 29의 -Z 목표로 되돌렸다. `ImmersiveBoxView.frontCorrectionAngle`은 이 함수를 쓰고, `DEBUG-FRONT` 로그에 "보정 후 nose XZ(목표 (0, -1))"를 같이 찍는다.
  - `KartModel.modelForwardCorrectionDegrees` fallback을 0 → 180으로 되돌렸다(마커가 있으면 쓰이지 않음).
  - `KartCoreTests`에 `KartForwardCorrectionTests` 5개 추가: +Z 마커 → 180도, -Z → 0도, ±X·대각선 → 모두 -Z로 수렴, 보정 뒤 정면이 heading 0에서 `KartMotionState`가 나아가는 방향과 일치, 영벡터 → nil. 다시는 눈대중으로 뒤집지 않도록 수학으로 고정.
- **교훈**: 입력(핸드 트래킹)과 표시(모델 축) 두 군데가 동시에 의심될 때는 `DEBUG-MOTION`의 `speed` 부호와 `pos` 변화로 입력부터 확정한 뒤 모델을 건드린다. 결정 32는 그 순서를 지키지 않았다.
- **확인**: visionOS 시뮬레이터 빌드 + `KartCoreTests` 통과(기존 `EngineSoundMachineTests` 5개 실패는 그대로). 실기기 확인은 사용자 몫 — "전진 시 카트 앞부분이 먼저 나가는지".
- **영향받는 절**: 결정 32번(폐기), `KartCore/KartForwardCorrection.swift`(신규), `ImmersiveBoxView.frontCorrectionAngle`, `KartCatalog.modelForwardCorrectionDegrees`, `KartCoreTests`

## 43. [테크] 디오라마 출발 방향 반전 — 트랙 JSON이 아니라 박스 표시를 180° 돌림

- **날짜**: 2026-10-11
- **요청**: 결정 42 확인 뒤 "디오라마 모드 시작 시 차량이 반대쪽을 바라보고 시작되면 좋겠다".
- **선택지**: (a) `track.start.heading`을 π 더하기 → 랩·체크포인트 판정이 경로 진행 방향을 따르므로 트랙을 거꾸로 도는 셈이 되어 `LapTracker`가 깨진다. (b) 트랙 JSON을 역방향으로 다시 생성 → 생성·검증 스크립트와 체크포인트 순서까지 손대야 한다. (c) **박스 안의 트랙 표시 전체를 180° 돌리기** → 주행·랩 로직은 트랙 좌표계 그대로, 사용자 쪽에서 보이는 것만 바뀐다. (c)를 골랐다.
- **구현**: `ImmersiveBoxView.trackDisplayYaw = π`. `worldToDisplay`가 트랙 중심 기준으로 R_y(ψ) 회전을 거친 뒤 배율을 곱하고, 타일 회전과 `kartSlot.orientation`에 같은 ψ를 더한다(표시 벡터 R_y(ψ)R_y(h)(-Z) = R_y(h+ψ)(-Z)). 1인칭의 머리 방향은 씬 좌표계 값이라 `tickMotion`에서 ψ를 빼 트랙 좌표계로 되돌린다 — 고개를 돌린 쪽으로 카트가 도는 관계는 그대로다. 디버그 트레일은 표시 좌표를 쓰므로 자동으로 따라온다. 리스폰은 트랙 좌표라 영향 없음.
- **확인**: visionOS 시뮬레이터 빌드 통과. `KartCoreTests`는 트랙 좌표계 로직만 다뤄 영향 없음. 실기기 확인: 출발 시 카트가 이전과 반대쪽을 보는지, 1인칭에서 고개 돌린 쪽으로 카트가 도는지.
- **영향받는 절**: `ImmersiveBoxView`(`trackDisplayYaw`, `worldToDisplay`, `placeTile`, `tickMotion`), README 사용법("좌/우는 카트 기준" 설명은 그대로 유효)

## 44. [테크] Phase 2 — 1인칭·3인칭 콕핏: 트랙 실제 크기 + 카트를 머리 위치에 따라붙임

- **날짜**: 2026-10-11
- **배경**: 결정 39에서 미뤄 둔 Phase 2. Phase 1의 1인칭·3인칭은 디오라마와 같은 작은 박스 안에서 조작법만 달랐다. 이제 두 모드는 트랙이 **실제 크기(타일 4 m)**로 사용자 주변에 깔리고, 카트가 사용자 위치에 "고정"돼 카트에 탄 듯 보인다.
- **구조**: 트랙 타일·카트·디버그 트레일을 전부 새 `sceneRoot` 아래 **트랙 좌표계(미터, 노면 y = 0) 실제 크기**로 둔다. 모드에 따라 `sceneRoot`의 변환(`world = position + scale · R_y(yaw) · local`) 하나만 바꾼다.
  - **디오라마**: scale = 박스 맞춤 배율(기존 `trackDisplayScale`), yaw = π(결정 43), position = 트랙 중심이 박스 바닥 중앙에. 카트 모델은 배율로 나눠 넣어 눈에 보이는 크기 0.12 m를 유지(기존 동작 그대로). 결정 43의 `worldToDisplay`/`trackDisplayYaw`는 이 변환으로 흡수돼 삭제.
  - **1인칭·3인칭(콕핏)**: scale = 1. 모드에 들어온 순간 머리 위치를 `cockpitAnchor`로, 머리 yaw로 `sceneYaw = headYaw − startHeading`을 잡아 **출발 방향이 사용자가 보는 쪽**이 되게 한다. 이후 매 프레임 `followKart()`가 "카트 트랙 좌표 → 콕핏 목표점"이 되도록 `sceneRoot.position`만 옮긴다 — **월드는 평행이동만 하고 돌지 않는다**(회전 vection이 멀미의 주범이라 의도적으로 뺐다). 1인칭 목표점 = 머리 아래 0.9 m(앉은 드라이버 눈높이), 3인칭 = 머리 아래 1.8 m + 카트 진행 방향(월드)으로 2.5 m 앞(`CockpitTuning`). 카트 모델은 전장 1.5 m 실제 크기.
  - 수학은 `KartCore/ScenePlacement.swift`(`forward`/`rotateY`/`rootPosition`/`sceneYaw`/`cockpitTarget`/`kartFitLength`)로 분리하고 `ScenePlacementTests` 6개로 고정했다(배치 왕복, heading 합성, 출발 방향 = 머리 방향, 모드별 목표점, 1인칭 따라붙기, 카트 크기).
- **모드 전환 시(`applyModeLayout`)**: 박스 프레임·바닥은 디오라마에서만 보이고, HUD는 콕핏 모드에서 머리 앞 1.2 m·0.15 m 아래에 고정(빌보드), 핀치 입력 캐처는 사용자 주변 40 m 상자로 넓힌다(핀치는 캐처를 봐야만 잡히므로 — 결정 26·33). 카트 모델은 모드에 맞춰 다시 맞춘다. 머리 방향 조향(`desiredHeading`)은 `sceneYaw`를 빼서 트랙 좌표계로 되돌린다(결정 43의 일반화).
- **의도적으로 안 한 것**: 스트리밍/컬링(트랙 16~64 타일이라 실기기 측정 후에만, 결정 39), 3인칭 추적 카메라식 월드 회전(멀미), 콕핏 내부(핸들·대시보드) 모델, 사용자가 걸어 다닐 때 anchor 갱신(들어온 순간 고정). 시뮬레이터처럼 월드 트래킹이 없으면 anchor (0, 1.2, 0)·yaw 0으로 대체.
- **확인**: visionOS 시뮬레이터 빌드 통과, `ScenePlacementTests` 6개 + 기존 테스트 통과(기존 `EngineSoundMachineTests` 5개 실패는 그대로). **실기기 확인 필요**: 1인칭에서 카트가 발밑/앞에 보이는지와 눈높이 0.9 m가 적절한지, 3인칭 2.5 m·1.8 m가 적절한지, 실제 크기 트랙에서 프레임이 떨어지지 않는지(떨어지면 컬링 착수), 모드 전환 후 핀치가 계속 잡히는지.
- **영향받는 절**: `Docs/TechTask.md` M2·M6, README(Phase 2), `KartCore/ScenePlacement.swift`(신규), `ImmersiveBoxView`(`sceneRoot`/`applyModeLayout`/`followKart`/`fitKart`/`currentHeadPose`), `KartCoreTests`

## 45. [테크] 3인칭 멀미 피드백: 카트를 카트 진행 방향이 아니라 "바라보는 방향" 앞에 둔다

- **날짜**: 2026-10-11
- **배경**: Phase 2(결정 44) 실기기 체크리스트는 전부 통과했으나(디오라마 동일, 1인칭 실제 크기·발밑·머리 조향, 3인칭 앞·아래, 콕핏 핀치·HUD), **3인칭에서 멀미**를 느꼈고 "카메라가 좌우로 틀 때도 카트가 중앙에 있었으면 한다"는 요청. 결정 44의 3인칭은 카트를 **카트 진행 방향** 2.5 m 앞에 두었기 때문에, 고개를 돌리면 카트가 시야 밖으로 나가고 다시 찾아야 했다 — 시선이 고정점을 잃는 것이 멀미의 원인이었다.
- **수정**: `ScenePlacement.cockpitTarget`에 `headYaw`를 추가해 3인칭의 "앞"을 **사용자가 바라보는 방향(월드 yaw)**으로 바꿨다. 이제 고개를 어느 쪽으로 돌려도 카트는 항상 시야 중앙 2.5 m 앞·1.8 m 아래에 있다(카트 모델은 자기 heading대로 돌아 있으므로 어디로 달리는지는 모델 방향으로 보인다). 머리 yaw는 `approachAngle`(최단 경로 지수 평활, `thirdPersonHeadYawSmoothingRate` 6/s)로 걸러 떨림이 카트 위치로 전달되지 않게 했다. `headYaw`가 없으면(시뮬레이터 등) 결정 44의 진행 방향 기준으로 돌아간다. 1인칭·디오라마는 변화 없음.
- **테스트**: `ScenePlacementTests`에 headYaw 분기와 `approachAngle`(비율·rate 0·큰 rate·±π 경계 최단 경로) 검증 추가.
- **확인**: visionOS 시뮬레이터 빌드·테스트 통과. **실기기 확인 필요**: 고개를 좌우로 돌릴 때 카트가 중앙에 머무는지, 평활 6/s가 끈적이지 않는지(느리면 10, 떨리면 4), 멀미가 줄었는지.
- **영향받는 절**: `KartCore/ScenePlacement.swift`(`cockpitTarget(headYaw:)`, `approachAngle`, `CockpitTuning.thirdPersonHeadYawSmoothingRate`), `ImmersiveBoxView.followKart(headYaw:deltaTime:)`, README 3인칭 설명

## 46. [테크] 3인칭 추적 카메라: 항상 카트 뒤에서 앞을 보도록 씬 yaw를 천천히 따라 돌림

- **날짜**: 2026-10-11
- **배경**: 결정 45(바라보는 방향 중앙 고정) 실기기 확인 — 카트 시야 중앙 유지 ✅, 멀미 감소 ✅. 추가 요청: "항상 카트의 뒤에서 앞을 보도록 해야 트랙을 알 수 있다". 결정 44·45는 멀미 때문에 **월드를 돌리지 않는** 원칙이었는데, 그러면 코너를 돈 뒤 카트가 옆이나 뒤를 향한 채 시야 중앙에 있어 앞 트랙이 안 보인다.
- **결정**: 3인칭에 한해 월드 회전을 허용하되 **평활**한다. 매 프레임 목표 씬 yaw = `chaseSceneYaw(kartHeading, headYaw) = headYaw − kartHeading`(지금 카트 heading의 월드 정면 = 바라보는 방향, 즉 카트 뒤에서 앞을 봄)을 구하고, `approachAngle`로 `thirdPersonChaseYawRate` 2.5/s만큼만 따라간다(90° 코너 후 1초에 약 92 %, 3초에 99.9 % 수렴). 평행이동(결정 45의 중앙 고정)은 그대로이므로 회전 피벗은 사실상 카트다 — 사용자 주변이 아니라 2.5 m 앞 카트를 중심으로 세계가 돈다. 1인칭은 변화 없음(월드 회전 없음 유지 — 머리 조향과 월드 회전을 섞으면 피드백 루프가 생긴다). 디오라마 변화 없음.
- **트레이드오프**: 회전 vection이 다시 들어가므로 멀미가 재발하면 `thirdPersonChaseYawRate`를 낮추거나(1.5) 결정 45 상태(0 = 회전 안 함)로 되돌린다. 값은 `CockpitTuning`에 있다.
- **테스트**: `ScenePlacementTests.chaseSceneYawPutsViewerBehindKart` — chase yaw 적용 시 카트 월드 정면 = 머리 방향, 90° 코너 후 평활 수렴 시간.
- **확인**: visionOS 시뮬레이터 빌드·테스트 통과. **실기기 확인 필요**: 코너 뒤 카트가 앞을 향해 트랙이 보이는지, 회전 속도 2.5/s가 어지럽지 않은지.
- **영향받는 절**: `KartCore/ScenePlacement.swift`(`chaseSceneYaw`, `CockpitTuning.thirdPersonChaseYawRate`), `ImmersiveBoxView.followKart`, README 3인칭 설명, `Docs/TechTask.md` Phase 2

## 47. [디자인] 10/11 테크·디자인 리뷰 회의 결과 — 1인칭 폐기, 3인칭 카메라 기준, 카트 움직임, 창 배치, 운전자, 속도계, 앱 이름

- **날짜**: 2026-10-11
- **결정자**: 디자인·테크 (리뷰 회의). 디자이너 메모를 프로젝트 용어로 정리하고 코드·RetireX 원본과 대조해 Issue #23~#31로 나눴다.

| # | 결정 | Issue | 담당 |
| --- | --- | --- | --- |
| 47-1 | **카트 자세 버그**: razr가 옆으로 약 45° 비틀림, arcrix·bogubkart가 노면에 반쯤 파묻힘, 5종 점검. 유력 원인은 이름 부분 일치 "front" 정면 보정, 노면 높이 0.25 m 누락, 모델 최저점 접지 | #23 | 테크 |
| 47-2 | **1인칭 모드 폐기**(멀미). 조작은 디오라마·3인칭의 손 핀치 방식으로 통일. 3인칭에도 후진을 넣어 디오라마와 같은 규칙으로 할지 테크와 확정 | #24 | 테크 |
| 47-3 | **3인칭 카메라 기준 = 카트 진행 방향**(사용자 머리 아님). 기준 방향은 모드 진입 순간 고정, 고개는 ±45° 자유, ±60°를 2초 넘으면 리센터(제안값). 카트는 가던 방향으로 계속 감 | #25 | 테크 |
| 47-4 | **카트 움직임**: 공통 피벗(`A`·`C` 앞바퀴, `B`·`D` 뒷바퀴, `steering_wheel`, `root`)에 RetireX `physics` 애니메이션 식을 옮김 — 바퀴 굴림(속도 비례), 앞바퀴 조향 30°, 핸들 82°(핀치 연동), 회전 시 차체 기울기 | #26 | 테크(사양 디자인) |
| 47-5 | **창 배치**: 디오라마를 열면 메뉴 창을 박스 위로(또는 박스를 창 아래로), 3인칭에서는 창을 트랙 밖으로 빼고 종료 시 정면으로 다시 엶 | #27 | 테크 |
| 47-6 | **HUD 속도계**: RetireX 계기판(`rxo_hud_dial.png`)을 재사용해 `Design/hud/`로 전달 | #28 | 디자인 → 테크 |
| 47-7 | **운전자 캐릭터**: 간단한 블록 캐릭터 `driver_01`, 카트별 좌석 표로 엉덩이를 의자 위에 정확히(±1 cm) | #29 | 디자인 + 테크 |
| 47-8 | **앱 이름 제안 "핀치 로버"(Pinch Rover)**(결정 7 보류 해소 후보). 상표·동명 앱 확인 후 확정 | #30 | 둘 다 |
| 47-9 | **검수 요청**: 회의 밖 사항은 테크 Claude가 문서·코드를 검수해 잘못 잡은 부분을 알려 줌. 디자인 쪽에서 찾은 시작 목록 첨부 | #31 | 테크 |

- **이 커밋에서 디자인이 같이 고친 것**: 디자인 PRD 1장(모드·앱 이름 행), 4장(완성형 카트 피벗·움직임 표, 운전자), 7장(속도계), 8장(창 배치), 9장(1인칭 폐기 표시, 디오라마 중립 문장 정정), 11장(모드별 시점 규칙), 15장(새 납품 항목).
- **영향받는 결정**: 39·40·41(1인칭 부분 폐기), 44(1인칭 콕핏 폐기, 3인칭 유지), 45·46(3인칭 기준을 머리 → 카트 진행 방향으로), 14(운전석 캐릭터 "해당 없음" 뒤집음)

## 48. [테크] M4 미니맵 1차: Diorama 테이블 + 트랙 JSON에서 바로 만든 지도, 모드별 배치

- **날짜**: 2026-10-11
- **배경**: Phase 2 종료 후 다음 마일스톤. 사용자가 Apple Diorama 샘플(`~/Downloads/Diorama`)을 전달해 M4를 시작했다. 디자인 쪽 추가 피드백과 실기기 피드백이 뒤따를 예정이라 1차는 "보이고 동기화되는 것"에 집중했다.
- **테크 PRD 9장과 다르게 한 것**: PRD는 Diorama의 Shader Graph 지형 재질 + 높이맵/궤적 **이미지**(`minimap_images.py`)를 쓰기로 했는데, 1차에서는 **트랙 JSON 중심선에서 바로 기하(납작한 상자 리본)를 생성**했다. 이유: (1) 이미지 파이프라인·Shader Graph 복사 없이 같은 원본(JSON)에서 나오므로 "주행 트랙과 항상 같다"는 목적은 동일하게 달성, (2) 디자인 PRD 6장의 요소(노면·테두리·궤적·깃발·라벨·마커·랩 텍스트)를 전부 코드로 색만 바꿔 조정할 수 있어 디자인 피드백 반영이 빠르다, (3) 미니맵 지형의 픽셀 룩은 어차피 Shader Graph에서 보간을 허용하기로 했던 부분(테크 PRD 12장). 높이맵 변위·등고선은 보류.
- **Diorama 샘플에서 가져온 것**: 받침 모델 `Diorama_Base.usdz`만. `KartSimulator/Resources/Minimap/`에 Apple 샘플 라이선스 전문(`LICENSE-Apple-Diorama-Sample.txt`)과 함께 넣고 LICENSE 5조에 고지했다(앱 안 포함은 허용, 단독 재배포·Apple 상표 사용 금지). 샘플의 뷰모델·새·구름·슬라이더·지역 투명도·`RealityKitContent` 패키지는 가져오지 않았다(테크 PRD 9장 "제거할 것"과 같고, 패키지 분리는 M0 보류 항목 그대로).
- **구성** (`RealityKit/MinimapBuilder.swift`, 모두 미니맵 로컬 m, 지름 0.24 기준):
  - 받침: `Diorama_Base`를 지름 0.24에 맞춰 상판이 y = 0에 오게 배치, 재질은 `ui-rim`으로 통일(디자인 PRD 6장 "이 부분만 매끈한 재질 허용"). 못 읽으면 원기둥 받침으로 대체.
  - 지형 원판 `ui-panel` → 노면 리본 3층(테두리 `mm-edge` 1.25배 폭, 노면 `mm-road`, 궤적 `ui-sky` 40 % 1/3 폭) → 출발 깃발(`ui-ink` 기둥 + `mm-finish` 깃발, 체커 무늬 보류) → 체크포인트 라벨(디스크 + 숫자 `generateText`, 미통과 `ui-ink` 40 % / 통과 `ui-cyan`) → 카트 마커(로드된 카트 복제본 1.5 cm + `ui-cyan` 그림자) → 랩 텍스트("1 / 3", 앞 가장자리 60° 기울임).
  - 투영은 `KartCore/MinimapProjection.swift`: 트랙 바운딩 박스(노면 반폭 포함)를 원에 내접하는 정사각형의 90 %에 등방 배율로 맞추고 중심을 원점에. 축은 트랙 좌표계 그대로라 heading을 그대로 쓴다. `MinimapProjectionTests` 4개.
  - 동기화(테크 PRD `MinimapSyncSystem` 역할)는 `ImmersiveBoxView.tickMotion`에서 `Minimap.update` 직접 호출(ECS 분리는 여전히 보류). `RaceHUDState`에 `kartMapPosition`·`kartHeading` 추가, `RaceModel.updateMap`으로 채운다.
  - 상호작용 없음: `InputTargetComponent`를 붙이지 않아 핀치는 그대로 `inputCatcher`로 간다.
- **배치**: 디오라마 = 박스 앞오른쪽 모서리 위(테크 PRD "우측 하단 모서리 안쪽, 트랙 위에 떠 있게"를 0.7 m 박스에 맞춤), 지름 0.16으로 축소, 바닥에서 7 cm 위. 콕핏 = 모드 진입 순간 머리 기준 앞 1.2 m·오른쪽 0.45 m·아래 0.45 m(HUD 오른쪽 아래), 지름 0.24, 상판을 사용자 쪽으로 35° 기울임, 랩 텍스트가 사용자를 향함. 지도 내용(`mapRoot`)은 `sceneYaw`만큼 돌려 박스/콕핏에서 보이는 트랙 방향과 맞춘다 — 3인칭은 진입 시점 값으로 고정(북쪽 고정식, 세계가 돌아도 지도는 안 돈다).
- **확인**: visionOS 시뮬레이터 빌드, `KartCoreTests` 12개(미니맵 4 + 씬 배치 8) 통과, `Diorama_Base.usdz`·라이선스 파일이 앱 번들에 들어감을 확인. **시각 확인은 못 했다** — 디바이스 인터랙션 도구가 visionOS 시뮬레이터를 지원하지 않아 박스를 열 수 없었다. 실기기에서 확인할 것: 미니맵이 박스 모서리에 보이는지·크기 0.16이 적당한지, 노면 리본 꺾임이 매끈한지, 라벨 숫자·랩 텍스트가 읽히는지, 마커가 카트를 따라 도는지, 콕핏에서 HUD 옆 위치·35° 기울기가 적절한지.
- **보류**: 체커 무늬 깃발, 지형 높이맵·등고선, `minimap_images.py`, 통과 색 전환 0.2초 애니메이션, 미니맵 Shader Graph.
- **영향받는 절**: `Docs/TechTask.md` M4, 테크 PRD 9장(이미지 → 기하로 대체), `KartCore/MinimapProjection.swift`(신규), `RealityKit/MinimapBuilder.swift`(신규), `Resources/Minimap/`(신규), `RaceHUDState`/`RaceModel`, `ImmersiveBoxView`, LICENSE 5조, README

## 49. [테크] 리뷰 회의(결정 47) 반영 1차: 1인칭 폐기·조작 통일, 3인칭 카메라 기준 = 카트 진행 방향, 카트 자세·엔진음 테스트 수정

- **날짜**: 2026-10-11
- **배경**: 디자인 PR #32·Issue #23~#31(결정 47)을 코드에 반영한 첫 묶음. 미니맵 1차(결정 48)와 같은 PR에 들어간다.
- **Issue #24 — 1인칭 폐기 + 조작 통일**: `ExperienceMode`는 `diorama`·`thirdPerson` 2종. `DriveState.headSteered`, `KartMotionState`의 `desiredHeading`/`steer`, `MotionTuning.steerRateDegrees`, `HandInputResolver`의 1인칭 분기, HUD 모드 버튼 3→2, 조작법 시트의 1인칭 세그먼트와 1인칭 그림 연결, 1인칭 테스트를 모두 제거했다. **조작 통일은 디자인 제안대로 "3인칭 = 디오라마와 완전히 같은 규칙(후진 포함)"으로 확정** — 추적 카메라가 카트 뒤에 붙어 있어 후진이 일반 레이싱 게임의 후진과 같은 느낌이고, 그림 한 벌(디오라마 5장)을 두 모드가 같이 쓸 수 있다. 그래서 `Assets.xcassets/Onboarding`의 `gesture_fp_*`·`gesture_tp_*` imageset 6개를 지웠다(`Design/onboarding/`의 SVG 정리는 디자인 몫).
- **Issue #25 — 3인칭 카메라 기준 = 카트 진행 방향**: 결정 45·46의 "머리 yaw" 기준을 버리고, 모드 진입 순간의 머리 yaw를 **기준 방향**(`ChaseCameraReference.forwardYaw`)으로 고정했다. 카트 위치는 기준 방향 2.5 m 앞·1.8 m 아래, 씬 yaw 목표는 `기준 − 카트 heading`(2.5/s 평활, 결정 46 유지). 고개를 돌려도 아무것도 따라오지 않아 양옆을 볼 수 있다. 머리가 기준에서 60°를 넘어 2초 이상 머물면 기준을 머리 쪽으로 1.0/s로 다시 맞춘다(몸을 돌려 앉은 경우). 값은 `CockpitTuning`(`freeLookDegrees` 45, `recenterThresholdDegrees` 60, `recenterHoldSeconds` 2, `recenterRate` 1.0). `ChaseCameraReferenceTests` 4개.
- **Issue #23 — 카트 자세(일부)**: ① 정면 마커를 이름 **부분 일치**("front") 대신 **정확 일치** 목록(`front_aero`, `race_nose`, `nose`, `front`)으로 찾는다 — razr에서 `front_l`(앞왼 바퀴 묶음)이 걸려 약 35° 비틀리던 원인 제거. ② 카트 높이를 노면 윗면(`TrackDefinition.roadSurfaceHeight` = 타일 4유닛 = 0.25 m)에 둔다 — 전에는 타일 바닥(0)에 두어 모든 카트가 0.25 m 가라앉았다. 콕핏 따라붙기·디버그 트레일도 같은 높이를 쓴다. ③ **바퀴 바닥 접지는 못 했다**: USDZ 5종을 열어 보니 RetireX 원본의 바퀴 피벗 `A`·`B`·`C`·`D`가 노드 이름으로 남아 있지 않다(남은 이름: `root`, `steering_wheel`/`steering_column`, `body`, `nose`, `race_nose` 등). glb→USDZ 변환에서 바퀴 그룹 이름이 사라진 것으로 보인다. 바퀴 기반 접지(#23)와 바퀴 굴림·조향(#26)은 **바퀴 그룹 이름이 보존된 재내보내기**가 있어야 한다 — Issue #23·#26에 코멘트로 요청.
- **Issue #31 — `EngineSoundMachineTests` 5개 실패 수정**: 원인 두 가지. (a) 시동 2.2초 판정이 `clipTime >= 2.2`인데 1/60초를 132번 더하면 부동소수점 누적으로 2.2에 아주 조금 못 미쳐 idle로 못 넘어갔고, 그 뒤 테스트가 전부 연쇄 실패했다 → `1e-6` 여유. (b) 이미 빠르게 달리는 중에 가속 클립을 시작하면 2.6초를 다 기다려야 루프로 넘어갔다 → 속도비 `rS ≥ 0.85`이고 클립 0.5초 이상이면 바로 루프(`EngineTuning.fastHandoffSpeedRatio`/`fastHandoffMinClipTime`). 가속 클립은 회전수가 올라가는 소리라 이미 최고 속도에 가까우면 음이 어긋나던 것이기도 하다. `Assets/sfx/ENGINE.md`(디자인 소유)에 이 규칙과 "2단계 전진 → 연속 페달" 반영은 디자인에 요청(Issue #31 코멘트).
- **확인**: visionOS 시뮬레이터 빌드, `KartCoreTests` 전체 통과(엔진음 5개 포함, 처음으로 전부 녹색). **실기기 확인 필요**: razr가 똑바로 서는지, 5종이 노면 위에 서는지(바퀴 접지는 아직), 3인칭에서 고개를 ±45° 돌려도 카트·세계가 고정인지, 60° 넘겨 2초 뒤 기준이 따라오는지, 3인칭 후진이 어지럽지 않은지.
- **영향받는 절**: 결정 39·44·45·46(1인칭·머리 기준 부분 폐기), `KartCore/ExperienceMode`·`DriveState`·`KartMotionState`·`MotionTuning`·`HandInputResolver`·`ScenePlacement`(`ChaseCameraReference`)·`TrackDefinition.roadSurfaceHeight`·`EngineSoundMachine`, `ImmersiveBoxView`, `ContentView`, `Assets.xcassets/Onboarding`, README, `Docs/TechTask.md`

## 50. [테크] Issue #31 검수 반영 1차: 라이선스·크레딧·문서 정정, 디버그 시각물 기본 끔

- **날짜**: 2026-10-11
- **반영**:
  - **OFL 동봉·크레딧**: `Design/fonts/OFL.txt`를 앱 번들 `KartSimulator/Resources/Fonts/OFL.txt`로 복사하고, 메뉴 하단에 "Galmuri 폰트 © Lee Minseo (quiple), SIL OFL 1.1 · 미니맵 받침 © Apple" 크레딧을 넣었다(OFL 1.1 요건). 저작권자 표기를 "quiple" → "Lee Minseo (quiple)"로 고쳤다.
  - **LICENSE 2조/5조 중복 해소**: RetireX 유래 자산(카트 모델·텍스처·썸네일·실루엣·색 체계)을 2조(공동 저작물)에서 빼고 5조로 일원화했다. 명의(개인 vs CYBOX)는 디자인 담당자가 확정한다고 명시. 엔진음 항목에 출처 사슬(CYBOX "XK ENGINE" → RetireX → 변환)과 `Design/audio/engine_preview.wav` 경로를 추가.
  - **결정 40 결정자 문구** 정정(디자인 요청·사양, 작성·머지는 테크 Claude, PR #16). `Docs/TechTask.md` 열린 질문 중 해소된 2건(스와치 40/14 pt = 결정 36-3, 타일 대체 텍스처 = 결정 38) 체크.
  - **디버그 시각물 기본 끔**: `ImmersiveBoxView.showsDebugVisuals = false` — 헤드 구슬·시선 막대·빨간 트레일 엔티티를 `isEnabled = false`로. 머리 yaw 계산(3인칭 리센터에 필요)과 `DEBUG-*` 로그는 유지. 시연 영상에 초록 막대가 보이던 문제 해소.
- **안 한 것 / 사용자 결정 필요**: `mms.usdz`(Mercedes 메타데이터)가 공개 히스토리 `02940f5`에 남아 있는 문제 — 히스토리 재작성(`git filter-repo`)은 모든 클론을 다시 받아야 하므로 두 담당자가 결정한다. 디자인 소유 문서(`Docs/design-prd.md` 13장 경로, `Assets/sfx/ENGINE.md` 연속 페달 표현, `icon_pinch_in` 폐기)는 Issue #31 코멘트로 디자인에 넘겼다.
- **영향받는 절**: `LICENSE`, `README.md` 라이선스 표, `Resources/Fonts/OFL.txt`(신규), `ContentView` 크레딧, `ImmersiveBoxView.showsDebugVisuals`, 결정 40, `Docs/TechTask.md`

## 51. [테크] 리뷰 회의 반영 2차: 창 배치(Issue #27), 카트 리그 — 핸들 82° 핀치 연동·차체 기울기(Issue #26 일부)

- **날짜**: 2026-10-11
- **Issue #27 창 배치**: visionOS는 첫 창의 위치를 시스템이 정하고 프로그램으로 옮길 수 없다(`defaultWindowPlacement`는 다른 창 기준 상대 배치만). 그래서 디자인 후보 (a)+(c)를 썼다.
  - 디오라마: **박스를 창 아래·앞으로** — `boxPosition` (0, 1.05, −1.1) → (0, 0.85, −0.9), 윗면 1.25 → 1.05 m. HUD·입력 캐처·미니맵은 `boxPosition` 기준이라 같이 내려간다. 창 아랫변과 실제로 안 겹치는지는 실기기에서 보고 더 내린다.
  - 3인칭: 들어갈 때 `dismissWindow(id: "menu")`로 메뉴 창을 치우고, 디오라마로 돌아오거나 HUD "박스 닫기"를 누르면 `openWindow(id: "menu")`로 사용자 정면에 다시 연다(창이 하나도 없으면 공간을 닫는 순간 앱이 사라지므로 **먼저** 연다). `WindowGroup`은 `openWindow`마다 새 창을 만들기 때문에 `ImmersiveSessionModel.menuWindowHidden`으로 우리가 숨긴 경우에만 다시 연다. `WindowGroup(id: AppScene.menuWindowID)`.
- **Issue #26 카트 리그(가능한 부분)**: USDZ에 남아 있는 `steering_wheel`(arcrix·bogubkart·gospel)/`steering_column`(razr·sirius)과 `root`로 **핸들 핀치 연동**과 **차체 기울기**를 넣었다. `KartCore/KartRigPose.swift`(순수 값, 테스트 4개): 조향 입력 `turnLeft` +1 / `turnRight` −1 → `lerp(dt × 14)` 평활 → 핸들 −steer × 82°(Z축), roll −steer × 속도비 × 4°(Z축), pitch 가속도비 × 1.5°(X축, `lerp(dt × 10)`), 바퀴 굴림 각속도 = 속도/반지름. `RealityKit/KartRig.swift`가 노드를 이름 정확 일치로 찾아 매 프레임 적용한다. 바퀴 `A`~`D`는 USDZ에 없어 코드만 준비해 두고 조용히 건너뛴다(재내보내기가 오면 바로 동작). 축 부호는 이 로스터(+Z 정면) 기준 추정이라 실기기에서 반대로 돌면 `KartRig`의 축 상수만 바꾼다.
- **확인**: visionOS 시뮬레이터 빌드, `KartCoreTests` 63개 통과. **실기기 확인**: 디오라마 열었을 때 창과 박스가 안 겹치는지, 3인칭에서 창이 사라지고 종료 시 정면에 다시 뜨는지, 왼손 핀치에 핸들이 왼쪽으로 82° 도는지(반대면 부호), 코너에서 차체가 바깥으로 살짝 기우는지(3인칭에서 멀미면 디오라마만).
- **영향받는 절**: `MyApp`(창 id), `AppScene.menuWindowID`, `ImmersiveSessionModel.menuWindowHidden`, `ImmersiveBoxView`(boxPosition·창 열고 닫기·`kartRig`), `KartCore/KartRigPose.swift`·`RealityKit/KartRig.swift`(신규), `Docs/TechTask.md`

## 52. [테크] 디자인 LICENSE 검토(Issue #34) 반영: 카트 자산 = 공동 저작물, Galmuri 연도, XK ENGINE 3.0.0

- **날짜**: 2026-10-11
- **배경**: 공동 저작권자 iMasterProX의 LICENSE 검토(Issue #34, `design` 브랜치 결정 "49"). PR #17에서 테크가 요청한 "RetireX 카트·팔레트 디자인 확인"에 대한 답이다. 결정 50에서 테크가 임시로 적었던 "CYBOX 허락 범위 안에서 포함, 명의는 디자인 확정"을 디자인 답변대로 바꿨다.
- **반영**:
  - LICENSE 2조: RetireX Online에서 가져온 카트 모델·텍스처·썸네일·실루엣과 색 체계를 **두 저작권자의 공동 저작물**에 포함(한·영). 5조의 CYBOX 허락 범위 문장 삭제, RetireX 항목은 참고 폴더·마인크래프트 요소 내용만 유지.
  - Galmuri 저작권자 "(c) 2019–2025 Lee Minseo (quiple)"(OFL.txt 1행 기준), LICENSE·README·앱 메뉴 크레딧 모두. `OFL.txt` 번들 동봉과 크레딧은 결정 50에서 이미 했다.
  - 엔진음 출처: "XK ENGINE 3.0.0(CYBOX)의 WAV, CC0 기반 녹음 변환", `Design/audio/engine_preview.wav` 경로(결정 50에 버전만 추가).
- **mms 히스토리 정리(49-2)는 보류 — 사용자 결정 필요**: `git filter-repo`로 `02940f5`의 `mms.usdz`를 지우고 `main`·`Dev`·`design`을 강제 푸시하는 작업은 되돌릴 수 없고 두 사람 모두 재클론해야 한다. 절차는 Issue #34에 정리돼 있고, 실행 시점·담당·GitHub Support 요청 여부를 두 분이 정한 뒤 테크가 실행한다.
- **결정 번호 정리**: `main`에는 47(디자인 리뷰 회의)·48(미니맵)·49(1차)·50(검수)·51(2차)·52(이 항목)가 있다. `design` 브랜치가 뒤늦게 47→48로 재번호하고 LICENSE 검토를 49로 적어 다시 충돌했다 → Issue #34 코멘트로 "`main` 번호 유지, 디자인 LICENSE 검토는 머지 시 **54**"를 제안했다(처음 53으로 제안했으나 테크 결정 53이 먼저 들어가 54로 정정). 앞으로는 번호를 매기기 전에 `main`과 상대 브랜치의 마지막 번호를 확인하고, 아직 머지 안 된 결정은 PR 본문에 "번호 미정(머지 시 확정)"으로 적는 것을 규칙으로 제안(디자인 PRD 13장은 디자인 소유라 요청).
- **영향받는 절**: `LICENSE` 2·5조, `README.md` 라이선스 표, `ContentView` 크레딧, 결정 50(일부 대체)

## 53. [테크] 3인칭 HUD·미니맵 머리 따라오기(탈출 경로), 앱 이름 "핀치 로버" 확정, mms는 히스토리 재작성 없이 제외 유지

- **날짜**: 2026-10-11
- **실기기 피드백(PR #35)**: 창 배치·핸들·차체 기울기는 만족. 다만 **3인칭에서 차를 세운 뒤 HUD 버튼을 다시 호버할 수 없어 탈출 경로가 없었다.** 결정 44·48에서 HUD·미니맵을 모드 진입 순간 머리 앞에 **고정**해 두었기 때문에, 추적 카메라로 몸·고개를 돌리거나 자리를 옮기면 HUD가 시야 밖(또는 등 뒤)에 남았다.
- **수정**: `ImmersiveBoxView.followHUD` — 3인칭에서 HUD와 미니맵이 매 프레임 머리 위치·yaw를 4/s 지수 평활로 따라온다(visionOS 시스템 UI의 느린 추종과 같은 느낌). 운전 중에는 거의 가만히 있고, 고개를 크게 돌리면 1초쯤 뒤 다시 앞에 온다. 디오라마는 그대로 박스 위 고정. 미니맵은 HUD 오른쪽 아래 상대 위치·35° 기울기를 유지하되, 실기기 피드백으로 **더 오른쪽 아래**(오른쪽 0.45 → 0.8 m, 아래 0.45 → 0.7 m)로 옮겨 트랙 시야를 가리지 않게 했다.
- **앱 이름 확정(결정 7 보류 해소, Issue #30)**: 디자인 제안 **"핀치 로버" / "Pinch Rover"**에 테크(사용자)가 동의했다. 반영: `Info.plist` `CFBundleDisplayName`, `ContentView` 제목(Galmuri), LICENSE 제목·2조·4조(옛 가칭 "핀치 카트"도 저작물 범위에 포함), README 제목·소개, TechTask. 디자인 소유 문서(PRD 1·15장, `Design/proposals/app-name.md`, 목업 `01_start`)는 디자인에 요청. App Store 동명 앱·상표 검색은 사용자가 직접 확인했다는 전제(상표 등록 여부는 별도).
- **mms(Issue #34 49-2)**: 사용자 결정 — **히스토리 재작성은 하지 않고** 프로젝트 파일에서 제외된 상태(`5c0c948`에서 삭제됨)를 유지한다. 저장소에 현재 파일은 없고, LICENSE 2조 저작물 범위에도 들지 않는다. GitHub Support 요청도 하지 않는다.
- **확인**: visionOS 시뮬레이터 빌드·테스트 63개 통과. 실기기: 3인칭에서 차를 세우고 고개를 돌려도 HUD가 1초 안에 앞에 와서 버튼이 호버되는지.
- **영향받는 절**: `ImmersiveBoxView.followHUD`/`hudFollowYaw`, `Info.plist`, `ContentView`, `LICENSE`, `README.md`, `Docs/TechTask.md`, Issue #30·#34
