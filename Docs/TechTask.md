# 핀치 카트 — 태스크 문서

Oct 10, 2026 · @Coulson 기준, `Docs/tech-prd.md`에서 파생. 마일스톤 순서대로 진행하고, 완료한 항목은 체크하며 날짜를 적는다. 결정이 바뀌면 `Docs/decisions.md`에 먼저 기록한다.

## 아키텍처 업데이트 (테크 PRD 대비 변경점)

테크 PRD 1장의 "기본 제안"에서 아래 3가지가 바뀌었다. 상세 이유는 `Docs/decisions.md` 참고.

1. **공간 구성**: Volumetric `WindowGroup` 대신 `ImmersiveSpace` + `.immersionStyle(selection:in: .progressive)`를 쓴다. 콘텐츠는 박스 모양 프레임(와이어프레임 엣지 + 바닥판)으로 경계를 표시한 디오라마이며, 사용자는 Digital Crown을 돌려 몰입도(이머시브 공간 ↔ 바깥 패스스루)를 조절한다.
2. **카트 에셋**: Blockbench 단일 모델(`kart_01`) 파이프라인 대신, 완성형 USDZ 6종(`arcrix`, `bogubkart`, `gospel`, `mms`, `razr`, `sirius`)을 1차 로스터로 쓴다. `mms`를 제외한 5종은 색상 16종(`black`/`blue`/`brown`/`cyan`/`gray`/`green`/`light_blue`/`lime`/`magenta`/`orange`/`pink`/`purple`/`red`/`silver`/`undyed`/`white`/`yellow`) 텍스처 변형을 갖고 있다.
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
- [ ] 카트 회전/관찰용 간단한 제스처(드래그로 회전) 추가 여부 결정 → 열린 질문에 기록

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

## M3 — 트랙 + 주행 로직 (2026-10-10 트랙 생성·검증 스크립트 완료)

- [ ] 트랙 타일 4종 에셋 확보 (디자인 PRD 5장 — Blockbench 파이프라인은 유지, 카트만 교체됨)
- [x] `Tracks/tools/gen_track.py`, `validate_track.py` 작성
  - 그리드 중앙 사각 루프 + "노치"(변 일부를 바깥으로 밀어내는 삽입)로 난이도별 복잡도 조절
  - 검증 5종 모두 구현: 단일 순환/연결 변 일치, path 닫힘·자기교차 없음, 출발선 위치, 체크포인트 개수·순서, 한 바퀴 길이 60~140m
  - easy/normal/hard × seed 1~8, 8×6 그리드로 24개 생성·검증 전부 통과
  - `Tracks/track_01.json`(seed 20261010, easy, 타일 16/64점), `Tracks/track_02.json`(seed 20261011, normal, 타일 18/72점) 커밋 — 아직 타일 3D 에셋이 없어 데이터만 존재, 렌더링은 타일 에셋 확보 후
  - **알게 된 점**: 노치 1개는 새 코너 2개뿐 아니라 노치 양옆의 기존 직선 타일 2개도 커브로 바꿔 커브 +4가 된다(+2 아님). 그래서 난이도는 "목표 커브 수"가 아니라 "노치 개수"로 조절한다(easy=0/4커브, normal=1/8커브, hard=2/12커브) — PRD의 "normal 6개"는 이 구조에서 나올 수 없어 8로 대체했다(`Docs/decisions.md` 17번)
- [ ] 박스 임시 주행장(M2) → 실제 트랙 좌표계·타일 배치로 교체
- [ ] 모션 튜닝을 실제 트랙 스케일 기본값으로 복원하고 트랙 JSON `tuning` 오버라이드 지원
- [ ] ECS 컴포넌트 6종 + 시스템 5종 구현 (테크 PRD 4장)
- [ ] 벽 충돌·트랙 이탈 복귀 로직

## M4 — 미니맵

- [ ] Diorama 샘플 이식, 트랙 JSON → 높이맵/궤적 이미지 생성 스크립트
- [ ] `MinimapSyncSystem` 구현
- [ ] 박스 다이오라마 안에서의 미니맵 배치 좌표 재계산 (볼륨 좌표계 → 이머시브 박스 좌표계로 변환 필요, 신규 항목)

## M5 — HUD·화면 흐름·효과음

- [ ] `RaceHUDState`/`RaceModel` 전체 필드 구현 (테크 PRD 10장) — `DriveState`/`HandStatus`는 M2에서 이미 KartCore에 구현됨, RaceModel은 이를 감싸기만 하면 됨
- [ ] 메뉴 4화면 + 볼륨 HUD 3상태 목업 반영
- [ ] 효과음 7종 연결

## M6 — 폴리시 · 출시 준비

- [ ] 성능 예산 측정 (90fps, 드로우콜 등 — 테크 PRD 12장)
- [ ] 앱 이름 확정 → `Docs/decisions.md`
- [ ] 아카이브 크기·메모리 예산 확인

## 열린 질문 (결정되면 `Docs/decisions.md`에 기록)

- [ ] 박스 다이오라마의 실제 치수(현재 0.7×0.4×0.7m 임시값, PRD 원안은 1.4×0.6×1.1m)를 그대로 쓸지
- [ ] 카트 6종을 모두 최종 로스터로 쓸지, 일부만 추릴지
- [ ] `mms`(색상 변형 없음, 텍스처 30MB로 용량 큼)를 1차 로스터에 포함할지
- [ ] 메뉴에서 카트를 360도 회전해 볼 수 있게 드래그 제스처를 넣을지
- [ ] Digital Crown 몰입도 범위(현재 0.0~1.0 임시값)를 얼마로 둘지, 레이싱 중에도 조절 허용할지
- [ ] M2 모션 튜닝 임시값(박스 스케일)을 M3에서 트랙 스케일로 복원할 때 느낌이 달라지는지 재검증 필요
