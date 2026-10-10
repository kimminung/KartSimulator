# 결정 기록

번호 · 결정 · 날짜 · 이유 순으로 적는다. PRD의 표에 번호가 있는 결정은 같은 번호를 쓴다.

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

## 20. 버그 수정: 박스 연 뒤 핀치 제스처가 완전히 무반응이던 문제

- **날짜**: 2026-10-10
- **증상**: 실기기에서 "박스 열기" 후 양손 핀치를 해도 카트가 전혀 반응하지 않았다(완전 무반응).
- **원인**: `ImmersiveBoxView`의 `driveGesture`가 `SpatialEventGesture()`를 어떤 엔티티도 조준하지 않은 채(`.targetedToEntity`/`.targetedToAnyEntity` 없이) 붙이고 있었다. RealityKit 공식 가이드("Responding to gestures on an entity")에 따르면 `RealityView` 안에서 제스처가 발생하려면 대상 엔티티에 `InputTargetComponent` + `CollisionComponent`가 반드시 있어야 하는데, 이 프로젝트에는 그런 엔티티가 아예 없었다. 테크 PRD 5장에 적어 둔 "InputCatcher" 엔티티를 실제로는 만들지 않고 넘어간 것이 원인 — PRD에 쓰기만 하고 구현을 빠뜨렸다.
- **진단 방법**: Apple 문서에서 `targetedToAnyEntity`/`InputTargetComponent` 관련 공식 가이드("Responding to gestures on an entity")를 확인해 "InputTargetComponent + CollisionComponent가 있는 엔티티만 이벤트를 받는다"는 조건을 재확인.
- **수정**: `inputCatcher`라는 보이지 않는 엔티티를 박스 위치에 두고 박스보다 넉넉한 크기(`boxSize * 3`)의 `CollisionComponent` + `InputTargetComponent`를 부여, `driveGesture`를 `SpatialEventGesture().targetedToEntity(inputCatcher)`로 바꿨다. 시뮬레이터에서 빌드·실행·유닛 테스트 23개 재확인 완료 — 다만 실제 손 핀치 인식 자체는 시뮬레이터로 검증 불가하므로 실기기 확인이 필요하다.
- **영향받는 절**: 테크 PRD 5장("InputCatcher" 설계를 실제로 구현), `Docs/TechTask.md` M2

## 21. 실기기 제스처 디버그 도구 추가 (임시)

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
