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
- **열린 질문**: `mms`는 색상 변형이 없고 텍스처 용량이 크다(약 30MB). 최종 로스터 포함 여부는 `Docs/tasks.md` 열린 질문 참고.

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
