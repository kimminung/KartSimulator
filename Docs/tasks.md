# 핀치 카트 — 태스크 문서

Oct 10, 2026 · @Coulson 기준, `Docs/tech-prd.md`에서 파생. 마일스톤 순서대로 진행하고, 완료한 항목은 체크하며 날짜를 적는다. 결정이 바뀌면 `Docs/decisions.md`에 먼저 기록한다.

## 아키텍처 업데이트 (테크 PRD 대비 변경점)

테크 PRD 1장의 "기본 제안"에서 아래 2가지가 바뀌었다. 상세 이유는 `Docs/decisions.md` 참고.

1. **공간 구성**: Volumetric `WindowGroup` 대신 `ImmersiveSpace` + `.immersionStyle(selection:in: .progressive)`를 쓴다. 콘텐츠는 박스 프레임(와이어프레임 + 바닥판)으로 경계를 표시한 디오라마이며, 사용자는 Digital Crown을 돌려 몰입도(이머시브 공간 ↔ 바깥 패스스루)를 조절한다.
2. **카트 에셋**: Blockbench 단일 모델(`kart_01`) 파이프라인 대신, 완성형 USDZ 6종(`arcrix`, `bogubkart`, `gospel`, `mms`, `razr`, `sirius`)을 1차 로스터로 쓴다. `mms`를 제외한 5종은 색상 16종(`black`/`blue`/`brown`/`cyan`/`gray`/`green`/`light_blue`/`lime`/`magenta`/`orange`/`pink`/`purple`/`red`/`silver`/`undyed`/`white`/`yellow`) 텍스처 변형을 갖고 있다.

## M0 — 프로젝트 셋업

- [x] visionOS 플랫폼 빌드 확인 (타깃은 이미 `xros`/`xrsimulator` 포함한 멀티플랫폼)
- [x] 카트 USDZ 6종을 프로젝트에 추가 (`KartSimulator/Resources/Karts/`)
- [ ] `KartCore` Swift 패키지 분리 (테크 PRD 3장) — 운동 모델·트랙 스키마를 macOS 단위 테스트로 검증할 수 있게. 아직 로직이 적어 보류, M3에서 착수
- [ ] `RealityKitContent` 패키지 분리 — 커스텀 컴포넌트가 생기는 M3부터 필요

## M1 — 박스 이머시브 공간 + 카트 쇼케이스 (이번 세션 범위)

- [x] `ImmersiveSpace` + 박스 프레임(와이어프레임) + 바닥판 다이오라마 구현
- [x] 메뉴 윈도우에 카트 6종 선택 그리드 + 색상 스와치(해당 카트만) 추가
- [x] 선택한 카트를 박스 안에 로드, 바운딩 박스 기준 자동 스케일·중앙 정렬
- [x] 색상 선택 시 베이스컬러/이미시브 텍스처 교체
- [ ] 실기기에서 Digital Crown으로 몰입도 조절 확인 (시뮬레이터는 크라운 입력 제한적 — 체크리스트에 남김)
- [ ] 카트 회전/관찰용 간단한 제스처(드래그로 회전) 추가 여부 결정 → 열린 질문에 기록

## M2 — 입력 프로토타입

- [ ] `InputCatcher` + `SpatialEventGesture` 기반 `DriveInputSystem` 구현 (테크 PRD 5장)
- [ ] 좌/우 핀치, 양손 벌림 거리로 `DriveState` 6종 판정 + 히스테리시스·그레이스 타이머
- [ ] 실기기 테스트: 손 구분 10/10, 벌림 경계 안정성 (테크 PRD 12장 체크리스트)
- [ ] 게이트 실패 시 ARKit `HandTrackingProvider` 전환 여부 결정 (테크 PRD 1장 (c))

## M3 — 트랙 + 주행 로직

- [ ] 트랙 타일 4종 에셋 확보 (디자인 PRD 5장 — Blockbench 파이프라인은 유지, 카트만 교체됨)
- [ ] `Tracks/tools/gen_track.py`, `validate_track.py` 작성
- [ ] ECS 컴포넌트 6종 + 시스템 5종 구현 (테크 PRD 4장)
- [ ] 카트 운동 모델(`KartCore/MotionTuning`) + 단위 테스트
- [ ] 벽 충돌·트랙 이탈 복귀 로직

## M4 — 미니맵

- [ ] Diorama 샘플 이식, 트랙 JSON → 높이맵/궤적 이미지 생성 스크립트
- [ ] `MinimapSyncSystem` 구현
- [ ] 박스 다이오라마 안에서의 미니맵 배치 좌표 재계산 (볼륨 좌표계 → 이머시브 박스 좌표계로 변환 필요, 신규 항목)

## M5 — HUD·화면 흐름·효과음

- [ ] `RaceHUDState`/`RaceModel` 전체 필드 구현 (테크 PRD 10장)
- [ ] 메뉴 4화면 + 볼륨 HUD 3상태 목업 반영
- [ ] 효과음 7종 연결

## M6 — 폴리시 · 출시 준비

- [ ] 성능 예산 측정 (90fps, 드로우콜 등 — 테크 PRD 12장)
- [ ] 앱 이름 확정 → `Docs/decisions.md`
- [ ] 아카이브 크기·메모리 예산 확인

## 열린 질문 (결정되면 `Docs/decisions.md`에 기록)

- [ ] 박스 다이오라마의 실제 치수(현재 1.4×0.6×1.1m 그대로 쓸지, 이머시브 공간에 맞게 축소할지)
- [ ] 카트 6종을 모두 최종 로스터로 쓸지, 일부만 추릴지
- [ ] `mms`(색상 변형 없음, 텍스처 30MB로 용량 큼)를 1차 로스터에 포함할지
- [ ] 메뉴에서 카트를 360도 회전해 볼 수 있게 드래그 제스처를 넣을지
- [ ] Digital Crown 몰입도 범위(현재 0.0~1.0 임시값)를 얼마로 둘지, 레이싱 중에도 조절 허용할지
