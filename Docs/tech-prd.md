# 핀치 카트 — 테크 PRD (macOS·Xcode·Blender MCP)

Oct 10, 2026 · @Coulson

## 1. 문서 전제

이 PRD는 요구상세서 12장의 "기본 제안"을 그대로 채택해 쓴 구현 명세다. 아래 결정 중 하나라도 바뀌면 오른쪽 열의 절을 고친다. 테크 담당은 macOS에서 Swift·SwiftUI·Xcode·Reality Composer Pro와 Blender MCP가 연결된 Claude로 작업하고, 레포는 [KartSimulator](https://github.com/kimminung/KartSimulator.git)의 `Dev` 브랜치를 쓴다.

| 번호 | 채택한 결정 | 바뀌면 영향받는 절 |
| --- | --- | --- |
| 1 | 공간 유형 (a) 볼륨 테이블탑 — 미니어처 트랙을 볼륨 안에 놓고 위에서 보며 조종 | 3, 5, 9, 12 |
| 2 | 회전 중 현재 속도 유지, 후진 없음 | 5, 6 |
| 3 | 전진 2단계(절반·최대), 손 벌림 거리로 구분 | 5, 6 |
| 4 | 핀치 감지는 SwiftUI SpatialEventGesture (ARKit 핸드 트래킹은 예비) | 5, 11 |
| 5 | 트랙은 사전 생성 후 레포 커밋 | 7 |
| 6 | 3랩 타임어택, 랩 수는 트랙 JSON 값 | 7, 10 |
| 8 | 카트는 `.glb`로 받고 테크가 Blender MCP로 USDZ 변환 | 8 |
| 9 | 트랙은 복셀 타일 조합, 런타임에 RealityKit이 타일 배치 | 7, 8 |
| 10 | 미니맵은 볼륨 안 우측 하단에 월드 고정 | 9 |
| 11 | 최소 visionOS 26 / Xcode 26 (작성 시점 최신 메이저) | 3, 12 |
| 12 | 효과음만, 배경음 없음 | 4, 10 |

**(c) 이머시브 3인칭으로 바꿀 때 달라지는 것**: 게임 씬이 `ImmersiveSpace`로 옮겨가고, 루트 엔티티 배율이 1:1이 되며, 카트 대신 트랙 루트가 움직인다. 입력은 ARKit `HandTrackingProvider`로 교체(손 추적 권한 필요)하고, 미니맵은 머리 고정(헤드락) attachment로 바뀐다. 그 외 ECS·트랙 데이터·에셋 파이프라인은 그대로다.

## 2. 시스템 개요

SwiftUI는 메뉴 윈도우와 게임 볼륨 두 씬만 가지고, 프레임마다 도는 게임 로직은 RealityKit 시스템 다섯 개가 순서대로 처리한다. 둘 사이에는 RaceModel 하나만 있어, 디자인 PRD의 HUD는 그 객체의 RaceHUDState 필드만 보면 된다.

## 3. 앱 구조

앱은 2D 메뉴 윈도우 하나와 게임 볼륨 하나로 이루어지고, 게임 상태는 `@Observable` 객체 하나(`RaceModel`)가 들고 SwiftUI·RealityKit 양쪽이 그것을 읽는다. 게임 로직은 RealityKit 시스템 안에서 프레임마다 돌고, SwiftUI는 상태를 표시만 한다.

**SwiftUI 씬**

| 씬 | 종류 | 내용 |
| --- | --- | --- |
| `MenuWindow` | `WindowGroup` (2D, 기본 600×480pt) | 시작 화면, 트랙 목록, 조작법, 결과 화면. 게임 중에는 닫히지 않고 뒤에 남음 |
| `RaceVolume` | `WindowGroup` + `.windowStyle(.volumetric)`, `defaultSize(width 1.4, height 0.6, depth 1.1, in: .meters)` | `RealityView` 하나. 트랙·카트·미니맵·HUD attachment가 모두 이 안에 있음 |

볼륨 안 좌표는 미터이며, 트랙 루트 엔티티에 배율 0.04(1:25)를 적용해 월드 단위(타일 4m)를 테이블 크기(타일 16cm)로 줄인다. 게임 로직은 모두 월드 단위로 계산하고 표시만 배율을 거친다.

**상태 관리**

| 객체 | 역할 |
| --- | --- |
| `RaceModel` (`@Observable`, `@MainActor`) | 세션 상태 머신(`idle → ready → countdown → racing → paused → finished`), 랩·타임, 선택된 트랙, HUD 상태 |
| `DriveInput` (struct) | 매 프레임 입력 스냅샷: 좌·우 핀치 여부, 손 사이 거리, 파생 상태(5장) |
| `TrackDefinition` (Codable struct) | 트랙 JSON 디코딩 결과(7장) |
| `RecordStore` | 트랙별 최고 기록 읽기·쓰기(11장) |
| `AudioPlayer` | 효과음 재생. `AudioFileResource`를 미리 로드 |

**모듈 구성 (Xcode 타깃·패키지)**

| 모듈 | 종류 | 내용 |
| --- | --- | --- |
| `KartSimulator` | visionOS 앱 타깃 | 씬, 뷰, `RaceModel`, 시스템 등록 |
| `RealityKitContent` | Reality Composer Pro Swift 패키지 | `.rkassets`(카트·타일·미니맵 USDZ, Shader Graph 재질), 커스텀 컴포넌트 정의 |
| `KartCore` | Swift 패키지 (플랫폼 독립) | 트랙 스키마·검증, 운동 모델 수식, 상태 머신. macOS에서 단위 테스트 가능 |
| `Tracks/tools` | Python 스크립트 | 트랙 생성·검증, 미니맵 이미지 생성 (앱 번들에 포함 안 함) |

`KartCore`를 분리하는 이유는 실기기 없이 macOS 테스트로 로직을 검증하고, Claude가 수정한 운동 모델을 즉시 돌려볼 수 있게 하기 위해서다.

## 4. RealityKit ECS

게임 로직은 컴포넌트 6개와 시스템 5개로 나누고, 매 프레임 입력 → 운동 → 충돌 → 랩 판정 → 표시 순으로 돈다. 커스텀 컴포넌트는 `RealityKitContent` 패키지에 두어 Reality Composer Pro 인스펙터에서도 값을 넣을 수 있게 한다.

**컴포넌트**

| 컴포넌트 | 붙는 엔티티 | 데이터 |
| --- | --- | --- |
| `KartComponent` | 카트 루트 | `speed`, `heading`(라디안), `tier`(0/1/2), 바퀴 엔티티 참조 4개 |
| `TrackComponent` | 트랙 루트 | `TrackDefinition` 참조, 월드→테이블 배율 |
| `CheckpointComponent` | 체크포인트 트리거 엔티티 | `index`, 통과 여부 |
| `StartLineComponent` | 출발선 트리거 엔티티 | 통과 방향 벡터 |
| `WallComponent` | 타일의 벽 콜리전 엔티티 | 벽 법선 벡터 |
| `MinimapMarkerComponent` | 미니맵 위 카트 마커 | 따라갈 카트 엔티티 참조, 미니맵 배율 |

**시스템 (등록 순서 = 실행 순서)**

| 시스템 | 입력 | 출력 |
| --- | --- | --- |
| `DriveInputSystem` | SpatialEventGesture가 넣어 준 최신 이벤트 버퍼 | `DriveInput` 스냅샷(상태·거리), `RaceModel.input` 갱신 |
| `KartMotionSystem` | `DriveInput`, `KartComponent`, `deltaTime` | 속도·헤딩 적분, 위치 이동, 바퀴 회전 애니메이션 |
| `CollisionResolveSystem` | 카트 콜리전 vs `WallComponent` 트리거 | 벽 접촉 시 속도 감쇠·슬라이드, 이탈 시 복귀 타이머 |
| `LapSystem` | 카트 vs `StartLineComponent`·`CheckpointComponent` | 체크포인트 순서 검증, 랩 완료, 타이머, 완주 판정 → `RaceModel` |
| `MinimapSyncSystem` | 카트 위치·헤딩 | 마커 엔티티 위치·회전 갱신, 통과한 체크포인트 색 변경 |

**규칙**

- 카트는 `PhysicsBodyComponent`를 쓰지 않는다(키네마틱 이동). 충돌은 `CollisionComponent` + `TriggerVolume`으로만 감지하고, 반응은 `CollisionResolveSystem`이 직접 계산한다.
- 시스템은 `racing` 상태에서만 카트를 움직이고, `countdown`·`paused`·`finished`에서는 입력을 읽되 적용하지 않는다.
- 효과음 트리거(카운트다운·체크포인트·랩·완주·벽 접촉)는 `LapSystem`·`CollisionResolveSystem`이 `RaceModel`에 이벤트를 넣고, SwiftUI 쪽 `AudioPlayer`가 재생한다.

## 5. 입력 파이프라인

볼륨 전체를 덮는 투명 입력 엔티티에 `SpatialEventGesture`를 걸어 시스템 핀치를 받고, 이벤트의 `chirality`(좌·우 손)와 `inputDevicePose`(손 위치)로 네 가지 조작 상태를 만든다. 손 추적 권한 없이 동작하는 것이 이 방식의 핵심 장점이다.

**감지 구조**

1. `RealityView` 안에 볼륨 크기의 보이지 않는 엔티티(`InputCatcher`)를 두고 `CollisionComponent` + `InputTargetComponent`를 붙인다. 사용자가 볼륨 어디를 보고 핀치해도 이 엔티티가 받는다.
2. `.gesture(SpatialEventGesture().targetedToEntity(InputCatcher))`에서 `onChanged`로 이벤트 모음을 받는다. 각 이벤트의 `phase`(`.active`/`.ended`/`.cancelled`), `chirality`, `inputDevicePose?.pose3D.position`을 `InputBuffer`에 기록한다.
3. `DriveInputSystem`이 매 프레임 버퍼를 읽어 `DriveInput`으로 변환한다. SwiftUI 이벤트와 RealityKit 프레임의 주기가 달라도 시스템 쪽이 항상 "마지막으로 알려진 상태"를 쓰므로 끊김이 없다.
4. HUD attachment(미니맵·숫자)는 `allowsHitTesting(false)`로 두어 시선이 거기 가 있어도 핀치가 `InputCatcher`로 간다.

**상태 결정 규칙**

| 조건 | `DriveState` | 비고 |
| --- | --- | --- |
| 좌·우 모두 핀치 아님 | `stopped` | 자연 감속 |
| 왼손만 핀치 | `turnLeft` | 속도 유지 |
| 오른손만 핀치 | `turnRight` | 속도 유지 |
| 양손 핀치, 거리 < 0.22m | `waiting` | 자연 감속 |
| 양손 핀치, 0.22m ≤ 거리 < 0.40m | `forwardHalf` | 목표 속도 = 최고 속도 × 0.5 |
| 양손 핀치, 거리 ≥ 0.40m | `forwardFull` | 목표 속도 = 최고 속도 |

거리는 두 손 `inputDevicePose` 위치 사이의 3D 거리이며, `inputDevicePose`가 없는 이벤트는 직전 값을 유지한다.

**수치 (코드 상수, `InputTuning`)**

| 상수 | 값 | 의미 |
| --- | --- | --- |
| `spreadHalf` | 0.22 m | 절반 속도 시작 거리 |
| `spreadFull` | 0.40 m | 최대 속도 시작 거리 |
| `spreadHysteresis` | 0.03 m | 단계 내려갈 때 추가로 더 좁혀야 하는 거리(떨림 방지) |
| `releaseGrace` | 120 ms | `.ended` 후 이 시간 안에 같은 손 `.active`가 오면 해제로 보지 않음 |
| `pinchDebounce` | 40 ms | 핀치 시작 후 이 시간 유지돼야 상태 반영 |
| `staleTimeout` | 300 ms | 이벤트가 이 시간 이상 안 오면 그 손은 추적 상실 → 해제 처리 + HUD 안내 |
| `distanceSmoothing` | 0.25 (EMA 계수) | 손 거리 지수 이동 평균 |

**예비 경로 (ARKit)**: `DriveInputProvider` 프로토콜 뒤에 `SpatialEventInputProvider`와 `HandTrackingInputProvider`(엄지·검지 끝 거리 < 1.5cm = 핀치)를 두고, 마일스톤 M1에서 SpatialEventGesture가 90Hz에서 손 구분·거리 안정성을 못 넘기면 ARKit으로 교체한다. 교체 시 1장의 (c) 변경점이 함께 적용된다.

## 6. 카트 운동 모델

카트는 물리 엔진 없이 속도 스칼라와 헤딩 각 하나로 움직이는 키네마틱 모델이며, 모든 값은 월드 단위(m, m/s, rad)로 계산한 뒤 표시 배율만 거친다. 아래 수치는 `KartCore`의 `MotionTuning` 기본값이고 트랙 JSON의 `tuning`으로 덮어쓸 수 있다.

**기본 수치**

| 상수 | 값 | 비고 |
| --- | --- | --- |
| `maxSpeed` | 4.0 m/s | 타일 4m 기준 한 바퀴 25~30초가 나오는 값 |
| `accel` | 3.0 m/s² | 목표 속도까지 가속 |
| `coastDecel` | 2.0 m/s² | 입력 없을 때 감속 |
| `brakeDecel` | 5.0 m/s² | `waiting`(양손 모음) 상태의 감속 |
| `turnRateLow` | 100 °/s | 속도 ≤ 절반일 때 회전 속도 |
| `turnRateHigh` | 70 °/s | 최고 속도에서의 회전 속도. 사이 값은 선형 보간 |
| `minTurnSpeed` | 0.3 m/s | 이보다 느리면 제자리 회전 허용(막힘 방지) |
| `wallSpeedKeep` | 0.5 | 벽 접촉 시 속도에 곱하는 계수 |
| `offTrackRespawn` | 2.0 s | 트랙 밖 체류 시 복귀까지 시간 |
| `respawnSpeed` | 0 m/s | 복귀 직후 속도 |

**프레임 갱신 (의사코드)**

```swift
let target = state.targetSpeed(tuning)          // stopped/turn: 유지, waiting: 0(brake), half/full
let rate = target > speed ? tuning.accel
         : (state == .waiting ? tuning.brakeDecel : tuning.coastDecel)
speed = approach(speed, toward: target, by: rate * dt)

if state == .turnLeft || state == .turnRight, speed >= tuning.minTurnSpeed || speed == 0 {
    let t = clamp(speed / tuning.maxSpeed, 0, 1)
    let rate = lerp(tuning.turnRateLow, tuning.turnRateHigh, t)
    heading += (state == .turnLeft ? 1 : -1) * rate * dt
}

let forward = SIMD3(-sin(heading), 0, -cos(heading))   // -Z가 정면
position += forward * speed * dt
wheelSpin += speed / wheelRadius * dt
```

**벽 충돌**

1. `CollisionResolveSystem`이 카트 콜리전 박스와 `WallComponent` 트리거의 겹침을 받는다.
2. 속도 벡터를 벽 법선 `n`에 대해 분해하고, 법선 성분을 제거한 접선 성분만 남긴다(슬라이드).
3. 속도 스칼라에 `wallSpeedKeep`을 곱하고, 카트를 법선 방향으로 겹친 깊이만큼 밀어낸다.
4. 같은 벽과 연속 접촉 중에는 2·3을 반복하되 효과음은 처음 한 번만 낸다.

**트랙 이탈 복귀**

1. 카트 중심이 트랙 폭(`width` + 여유 0.5m) 밖에 있으면 `offTrackTimer`를 누적한다.
2. 2.0초를 넘으면 마지막으로 통과한 체크포인트(없으면 출발선)의 위치·방향으로 카트를 옮기고 속도를 0으로 둔다.
3. 복귀 중 0.5초는 입력을 무시하고 HUD에 "복귀" 표시를 낸다. 랩 타이머는 계속 간다(페널티 역할).

## 7. 트랙 데이터

트랙 하나는 `Tracks/track_XX.json` 파일 하나이며, 타일 격자가 원본이고 중심선·체크포인트·미니맵 이미지는 모두 그 격자에서 스크립트로 파생된다. 앱은 JSON을 읽어 타일 USDZ를 격자 위치에 배치하고, 중심선으로 랩 판정과 이탈 판정을 한다.

**좌표계**

- 월드 단위 미터. 격자 원점은 트랙 루트의 (0, 0), `+X` 오른쪽, `-Z` 앞(북). 타일 `(col, row)`의 중심 = `(col × tileSize + tileSize/2, 0, -(row × tileSize + tileSize/2))`.
- 타일 회전 `rot`은 0·90·180·270도, Y축 기준 시계 방향. 타일 USDZ는 `rot = 0`일 때 입구가 남(`+Z`), 출구가 북(`-Z`)인 방향으로 만든다(디자인 PRD 5장).

**타일 종류**

| `type` | 입구 → 출구 (`rot = 0`) | 용도 |
| --- | --- | --- |
| `straight` | 남 → 북 | 직선 |
| `curve` | 남 → 동 | 90° 우회전. `rot`으로 네 방향, 좌회전은 진행 방향이 반대인 같은 타일 |
| `start` | 남 → 북 | 출발·결승선이 그려진 직선. 트랙당 1개 |
| `grass` | 없음 | 트랙이 지나지 않는 칸을 채우는 바닥. 생략 가능 |

**JSON 스키마**

```json
{
  "schemaVersion": 1,
  "id": "track_01",
  "name": "첫 바퀴",
  "difficulty": "easy",
  "seed": 20261010,
  "laps": 3,
  "tileSize": 4.0,
  "width": 3.0,
  "grid": { "cols": 8, "rows": 6 },
  "tiles": [
    { "col": 1, "row": 0, "type": "start", "rot": 0 },
    { "col": 1, "row": 1, "type": "curve", "rot": 0 }
  ],
  "path": [ { "x": 6.0, "z": -2.0 }, { "x": 6.0, "z": -6.0 } ],
  "start": { "pathIndex": 0, "heading": 0.0 },
  "checkpoints": [ 7, 14, 21 ],
  "walls": true,
  "tuning": { "maxSpeed": 4.0 }
}
```

| 필드 | 규칙 |
| --- | --- |
| `tiles` | 격자 위 트랙 타일 목록. 같은 칸 중복 금지 |
| `path` | 중심선을 1m 간격으로 샘플링한 닫힌 점열. `tiles`에서 생성(수기 편집 금지) |
| `start.pathIndex` | 출발선이 놓인 `path` 인덱스. `start` 타일 중심과 일치 |
| `start.heading` | 출발 시 카트 헤딩(rad). 0 = `-Z` |
| `checkpoints` | `path` 인덱스 3개 이상, 오름차순, 출발선 기준 대략 1/4·1/2·3/4 지점 |
| `tuning` | `MotionTuning` 필드 일부만 덮어쓰기 가능 |

**생성 스크립트 (`Tracks/tools/gen_track.py`)**

1. 입력: `--seed`, `--cols`, `--rows`, `--difficulty`(easy: 커브 4개, normal: 6개, hard: 8개 이상).
2. 격자 위에서 자기 자신과 닿지 않는 단순 순환(simple cycle)을 랜덤 워크 + 백트래킹으로 찾는다. 인접한 두 칸은 변 하나만 공유해야 한다(대각선·접촉 금지).
3. 순환의 각 칸에 직선/커브 타일과 `rot`을 배정하고, 가장 긴 직선 구간 가운데를 `start`로 둔다.
4. 중심선을 1m 간격으로 샘플링해 `path`를 만들고 체크포인트 인덱스를 계산한다.
5. `validate_track.py`를 통과하면 JSON과 미니맵 이미지(9장)를 함께 쓴다.

**Claude에게 트랙 생성을 시킬 때의 프롬프트**

```markdown
Tracks/tools/gen_track.py를 실행해 seed 20261011, 8×6, difficulty normal 트랙을 만들고
validate_track.py로 검증한 뒤 Tracks/track_02.json과 미니맵 이미지를 커밋해 주세요.
스크립트를 고치지 말고, 검증에 실패하면 seed를 바꿔 다시 시도하세요.
```

**검증 스크립트 (`validate_track.py`)**: 타일이 단일 순환을 이루는지, 모든 연결 변이 맞물리는지, `path`가 닫혀 있고 자기 교차가 없는지, `start`가 `start` 타일 위인지, 체크포인트가 3개 이상·오름차순인지, 한 바퀴 길이(`path` 점 수)가 60~140m인지 검사한다. 하나라도 실패하면 0이 아닌 코드로 종료하고 CI에서 PR을 막는다.

## 8. 에셋 파이프라인

디자이너가 올린 `.glb`를 테크의 Blender MCP Claude가 열어 원점·배율·방향을 맞추고 USDZ로 내보낸 뒤 Reality Composer Pro 패키지에 넣는다. 사람 손이 가는 단계는 "확인"뿐이고, 변환은 Blender 스크립트로 재현 가능해야 한다.

디자이너는 상단 세 단계만, 테크는 하단 네 단계만 맡고, 리뷰 렌더가 디자이너에게 되돌아가는 것이 유일한 역방향 흐름이다.

**Blender MCP Claude가 하는 일 (`Assets/tools/convert_asset.py`로 재현)**

1. `Assets/export/glb/<name>.glb` 임포트. 단위는 미터, Blockbench 16유닛 = 1m가 맞는지 바운딩 박스로 확인(카트 길이 1.4~1.6m).
2. 원점을 바닥 중앙으로, 정면을 `-Z`로 맞춘다. 바퀴 4개 오브젝트는 이름(`wheel_fl` 등)을 유지하고 원점을 바퀴 중심으로 둔다.
3. 텍스처는 그대로 두고, 재질이 하나인지와 알파 없음인지 확인한다. 발광 텍스처가 있으면 `emissive`로 연결한다.
4. `Assets/export/usdz/<name>.usdz`로 내보낸다(Blender USD 익스포터가 `.usdz`를 직접 못 쓰는 버전이면 `.usdc`로 내보내고 Reality Converter 또는 `usdzconvert`로 패키징).
5. 위에서 본 렌더 1장과 정면 렌더 1장을 `Assets/review/<name>_<date>.png`로 저장해 디자이너 확인용으로 커밋한다.
6. 트랙 타일은 같은 절차를 거친 뒤, 4종(`straight`·`curve`·`start`·`grass`)을 Blender에서 임시로 2×2 배치해 이음새가 맞는지 렌더로 확인한다.

**Reality Composer Pro 쪽**

- USDZ를 `RealityKitContent.rkassets/Models/`에 넣고, 카트는 `Kart.usda`, 타일은 `Tile_Straight.usda` 등 씬 하나씩으로 감싼다. 씬에서 `CollisionComponent`·`InputTargetComponent`·커스텀 컴포넌트를 붙인다.
- 타일 씬에는 벽 콜리전(얇은 박스, `WallComponent`)과 체크포인트·출발선 트리거를 놓을 빈 트랜스폼을 미리 둔다.
- 런타임에는 `Entity.load(named:in:)`로 타일 씬을 한 번 로드하고 `clone(recursive:)`으로 격자에 배치한다.

**픽셀 질감 유지 (최근접 샘플링)**

로드 직후 모든 `ModelComponent`의 `PhysicallyBasedMaterial`을 순회해 `baseColor` 텍스처의 샘플러를 교체한다.

```swift
var desc = MTLSamplerDescriptor()
desc.minFilter = .nearest; desc.magFilter = .nearest; desc.mipFilter = .notMipmapped
let sampler = MaterialParameters.Texture.Sampler(desc)
material.baseColor = .init(texture: .init(resource, sampler: sampler))
```

텍스처 압축(ASTC 등)은 끄고 PNG 원본을 쓴다. 크기가 2의 거듭제곱이 아니면 변환 스크립트가 거부한다.

**배율**

| 대상 | 월드 크기 | 볼륨 표시 크기 (×0.04) |
| --- | --- | --- |
| 타일 | 4.0 m | 16 cm |
| 카트 길이 | 1.5 m | 6 cm |
| 8×6 트랙 | 32 × 24 m | 128 × 96 cm |
| 미니맵 테이블 | — | 24 × 18 cm (트랙 JSON 기준 자동 배율) |

## 9. 미니맵

[Diorama 샘플](https://developer.apple.com/documentation/visionos/diorama)의 테이블·지형 엔티티와 Shader Graph 지형 재질을 가져와, 높이맵을 트랙 JSON에서 생성한 이미지로 바꾸고 카트 마커를 올린다. 슬라이더·새·구름·상세 패널은 모두 뺀다.

**가져올 것 / 제거할 것**

| Diorama 요소 | 처리 |
| --- | --- |
| `DioramaAssembled` 씬의 테이블 모델, `FlatTerrain` 디스크, 트레일 선 엔티티 | 복사해 `Minimap.usda` 씬으로 재구성. 트레일 선은 트랙 궤적 메시로 교체 |
| `DynamicTerrainMaterialEnhanced` 재질 + 등고선·정점 변위 서브그래프 | 복사. 두 높이맵 입력 중 하나에 우리 높이맵을 넣고 `Progress` = 0 고정 |
| `PointOfInterestComponent`, `PointOfInterestRuntimeComponent`, attachment 생성 코드 | 체크포인트·출발선 표시용으로 유지. `LearnMoreView`는 이름만 보이는 작은 라벨로 교체 |
| `Entity.load(named:in:)` 로드 코드, `AttachmentProvider` | 그대로 사용 |
| 새·구름 씬, `FlockingComponent`/시스템, 지역별 투명도 컴포넌트, 슬라이더 UI | 제거 |
| 샘플 라이선스 | Apple 샘플 코드 라이선스 문구를 `NOTICE`에 기재 |

**트랙 JSON → 이미지 (`Tracks/tools/minimap_images.py`)**

| 출력 | 규격 | 내용 |
| --- | --- | --- |
| `track_XX_height.png` | 512×512, 8비트 회색 | 바닥 0.45, 트랙 폭 안 0.60, 트랙 가장자리 0.55. 지형 재질이 트랙을 살짝 도드라지게 변위 |
| `track_XX_trail.png` | 512×512, RGBA | 중심선을 선폭 6px로 그린 궤적. 트레일 메시의 텍스처로 사용 |
| `track_XX_minimap.json` | 작은 JSON | 월드→이미지 변환(원점·배율), 체크포인트·출발선의 이미지 좌표 |

이미지는 트랙 격자 전체(`cols × tileSize` × `rows × tileSize`)에 10% 여백을 둔 정사각 영역을 512px로 매핑한다. 생성 스크립트가 트랙 JSON과 함께 커밋하므로 미니맵은 항상 주행 트랙과 같은 원본에서 나온다.

**배치와 동기화**

- `Minimap` 엔티티는 트랙 루트의 자식이 아니라 볼륨 루트의 자식으로 두고, 볼륨 우측 하단 모서리에서 안쪽으로 (x: +0.50, y: +0.10, z: +0.35)m에 고정해 트랙 위에 떠 있게 한다(어떤 타일이 아래 와도 가리지 않음). 테이블 지름 24cm.
- `MinimapSyncSystem`이 매 프레임 카트 월드 좌표를 `track_XX_minimap.json`의 변환으로 미니맵 로컬 좌표로 바꿔 마커 엔티티에 넣는다. 마커 회전 = 카트 헤딩.
- 마커는 카트 USDZ를 0.25배로 복제한 것. 체크포인트 라벨은 `PointOfInterestComponent` 트랜스폼으로 두고 통과 시 라벨 배경색을 바꾼다.
- 미니맵 엔티티에는 `InputTargetComponent`를 붙이지 않아 핀치가 `InputCatcher`(5장)로 간다.

## 10. HUD·미니맵 데이터 인터페이스

SwiftUI HUD와 미니맵 시스템은 `RaceModel`이 매 프레임 갱신하는 `RaceHUDState` 하나만 읽는다. 디자인 PRD의 HUD 요소는 이 구조체의 필드와 1:1로 대응해야 하며, 필드가 늘면 두 PRD를 같이 고친다.

```swift
public enum SessionPhase { case idle, ready, countdown(Int), racing, paused, finished }
public enum DriveState { case stopped, waiting, forwardHalf, forwardFull, turnLeft, turnRight }

public struct HandStatus { public var tracked: Bool; public var pinching: Bool }

public struct RaceHUDState {
    public var phase: SessionPhase
    public var lap: Int                 // 1부터, 완주 시 totalLaps
    public var totalLaps: Int
    public var lapTime: TimeInterval    // 현재 랩
    public var totalTime: TimeInterval
    public var bestLapTime: TimeInterval?
    public var speedKmh: Double         // 월드 속도 × 3.6
    public var drive: DriveState
    public var left: HandStatus
    public var right: HandStatus
    public var checkpointsPassed: Int   // 이번 랩에서
    public var totalCheckpoints: Int
    public var respawning: Bool
    public var kartMapPosition: SIMD2<Float>   // 미니맵 로컬 좌표 (m)
    public var kartHeading: Float              // rad
}

public struct RaceResult {
    public var trackId: String
    public var lapTimes: [TimeInterval]
    public var totalTime: TimeInterval
    public var isNewRecord: Bool
}
```

| 소비자 | 읽는 필드 | 갱신 주기 |
| --- | --- | --- |
| HUD attachment (랩·타임·속도) | `lap`, `totalLaps`, `lapTime`, `totalTime`, `speedKmh` | 매 프레임 (`TimelineView` 또는 `@Observable` 구독) |
| 핀치 상태 아이콘 | `drive`, `left`, `right`, `respawning` | 변경 시 |
| 손 안내 배너 | `left.tracked`, `right.tracked` | 변경 시 |
| 카운트다운 오버레이 | `phase == .countdown(n)` | 1초마다 |
| `MinimapSyncSystem` | `kartMapPosition`, `kartHeading`, `checkpointsPassed` | 매 프레임 |
| 결과 화면 | `RaceResult` | 완주 시 1회 |

효과음 이벤트는 별도 `enum RaceEvent { countdownTick, go, checkpoint, lapComplete, finish, wallBump, respawn }`로 `RaceModel.events`에 쌓이고 `AudioPlayer`가 소비한다. 디자인 PRD 10장의 효과음 목록은 이 enum 케이스 이름을 그대로 쓴다.

## 11. 저장·설정·권한

저장하는 것은 트랙별 최고 기록뿐이고, 모든 튜닝 값은 코드 상수와 트랙 JSON에 있으며, 기본 입력 방식에서는 별도 권한을 요청하지 않는다.

| 항목 | 방식 |
| --- | --- |
| 최고 기록 | `UserDefaults` 키 `record.<trackId>` 에 `RaceResult`를 JSON으로 저장. 랩별 시간·총 시간·날짜 포함 |
| 첫 실행 플래그 | `UserDefaults` 키 `onboarding.seen`. 조작법 자동 표시 여부 |
| 튜닝 상수 | `KartCore`의 `InputTuning`·`MotionTuning` 구조체 기본값. 디버그 빌드에서만 메뉴 윈도우에 슬라이더를 노출해 실기기 튜닝 후 코드에 반영 |
| 트랙 목록 | 앱 번들 `Tracks/` 폴더의 JSON을 실행 시 스캔. 순서는 `difficulty` → `id` |
| 권한 | SpatialEventGesture 경로: 없음. ARKit 경로로 바꾸면 `NSHandsTrackingUsageDescription`에 "손의 핀치 동작으로 카트를 조종하기 위해 손 위치를 사용합니다" |
| 네트워크 | 사용 안 함. `Info.plist`에 네트워크 관련 키 없음 |
| 로그 | `os.Logger` 카테고리 `input`, `motion`, `lap`, `asset`. 릴리스 빌드는 `error` 이상만 |

## 12. 성능 예산과 테스트

목표는 주행 중 90Hz 유지와 입력 지연 100ms 이내이며, 복셀 에셋이라 삼각형 수보다 드로 콜과 텍스처 샘플러 교체가 병목이 되기 쉽다.

**예산**

| 항목 | 한도 | 측정 |
| --- | --- | --- |
| 프레임 | 90 fps, 1분 주행 중 드랍 프레임 ≤ 0.5% | Instruments → RealityKit Trace |
| 입력 지연 | 핀치 상태 변화 → 카트 속도 변화 ≤ 100 ms | 로그 타임스탬프 차이 (`input`↔`motion`) |
| 드로 콜 | 프레임당 ≤ 120 | RealityKit Trace. 타일은 `clone`으로 메시 공유, 같은 재질 유지 |
| 삼각형 | 씬 전체 ≤ 300k | Reality Composer Pro 통계 |
| 텍스처 | 각 ≤ 1024², 총 ≤ 64 MB | 변환 스크립트가 검사 |
| 메모리 | 앱 ≤ 600 MB | Xcode Memory Gauge |
| 씬 로드 | 트랙 선택 → 주행 가능 ≤ 3 s | `os_signpost` |
| 앱 크기 | ≤ 100 MB | 아카이브 크기 |

**실기기 테스트 체크리스트 (마일스톤마다 반복)**

- [ ] 양손 핀치 → 손 구분이 10회 중 10회 맞는다 (왼손만, 오른손만 각 10회)
- [ ] 벌림 0.22m·0.40m 경계에서 단계가 오르내릴 때 카트가 덜컥거리지 않는다
- [ ] 한 손이 시야 밖으로 나가면 300ms 안에 해제 처리되고 안내가 뜬다
- [ ] 미니맵·HUD를 응시한 채 핀치해도 카트가 움직인다
- [ ] 벽에 정면으로 박았을 때 뚫고 나가지 않고 미끄러진다
- [ ] 트랙 밖에서 2초 뒤 마지막 체크포인트로 돌아온다
- [ ] 역주행으로 출발선을 지나도 랩이 올라가지 않는다
- [ ] 3랩 완주 시 결과 화면이 뜨고 최고 기록이 저장·표시된다
- [ ] 앱 전환 후 복귀 시 카트가 멈춰 있고 타이머가 멈춰 있다
- [ ] 볼륨을 옮기거나 크기를 바꿔도 미니맵이 우측 하단에 남아 있다
- [ ] 1분 주행 RealityKit Trace에서 프레임 드랍 ≤ 0.5%

**단위 테스트 (`KartCore`, macOS에서 실행)**: 상태 결정 규칙 6경우, 히스테리시스·그레이스 타이머, 운동 모델 1초 적분 결과, 벽 슬라이드 벡터 계산, 체크포인트 순서 검증, 트랙 JSON 디코딩·검증기 실패 케이스.

## 13. 마일스톤

단계는 순서대로 진행하고 게이트를 통과한 날짜를 `Docs/decisions.md`에 적는다. 기간은 정하지 않았으며, M1이 실패하면 1장의 (c) 변경점을 적용한 뒤 M1을 다시 한다. 디자이너 쪽 에셋은 M2 시작 전에 카트, M3 시작 전에 타일 4종이 필요하다.

## 14. 레포·브랜치 운영

레포는 [github.com/kimminung/KartSimulator](https://github.com/kimminung/KartSimulator.git) 하나이며, 테크는 `Dev`, 디자이너는 `design` 브랜치에서 작업하고 `main`으로 PR을 보낸다. `main`은 항상 Xcode에서 빌드되는 상태를 유지한다.

**브랜치**

| 브랜치 | 담당 | 규칙 |
| --- | --- | --- |
| `main` | 공용 | 직접 푸시 금지. PR 머지만. 머지 전 `validate_track.py`와 `KartCore` 테스트 통과 |
| `Dev` | 테크 | 앱 코드, `KartCore`, `Tracks/`, `Assets/export/`, `Assets/review/`. 작은 단위로 자주 커밋 |
| `design` | 디자이너 | `Assets/blockbench/`, `Assets/export/glb/`, `Design/`, `Docs/design-prd.md` |

**머지 흐름**

1. 디자이너가 `design`에 에셋을 올리고 `main`으로 PR → 테크가 Blender MCP로 변환·확인 후 승인·머지.
2. 테크가 `Dev`에서 `main`을 자주 당겨(`git merge main`) 새 에셋을 반영하고, 변환 결과 USDZ와 리뷰 캡처를 `Dev`에 커밋.
3. 마일스톤 끝마다 `Dev` → `main` PR. 태그 `v0.1`~.
4. 두 브랜치가 같은 파일을 고치지 않도록 폴더 소유권을 지킨다. 예외는 `Docs/decisions.md`뿐이며 충돌 시 PR 코멘트로 조율.

**폴더 구조**

```markdown
/CLAUDE.md                     두 Claude 공통 규칙 (아래)
/Docs/requirements.md          요구상세서
/Docs/tech-prd.md              이 문서
/Docs/design-prd.md            디자인 PRD
/Docs/decisions.md             결정 기록 (번호·결정·날짜·이유)
/App/KartSimulator.xcodeproj
/App/KartSimulator/            앱 타깃 소스
/App/RealityKitContent/        RCP 패키지
/App/KartCore/                 로직 Swift 패키지 + 테스트
/Assets/blockbench/            .bbmodel + 텍스처 (디자이너)
/Assets/export/glb/            디자이너 내보내기
/Assets/export/usdz/           테크 변환 결과
/Assets/review/                확인 렌더 PNG
/Assets/tools/convert_asset.py Blender 변환 스크립트
/Tracks/track_01.json ...      트랙 + 미니맵 이미지
/Tracks/tools/                 gen_track.py, validate_track.py, minimap_images.py
/Design/                       목업·아이콘·스타일 가이드 (디자이너)
/.gitattributes                *.glb *.usdz *.png *.wav → Git LFS
```

**`CLAUDE.md`에 들어갈 내용 (테크 쪽 Claude용)**

- 작업 전 `Docs/tech-prd.md`와 `Docs/decisions.md`를 읽는다.
- `Assets/blockbench/`와 `Design/`은 수정하지 않는다. 에셋 문제는 GitHub Issue로 남긴다.
- 에셋 변환은 `Assets/tools/convert_asset.py`로만 하고, 손으로 고친 USDZ는 커밋하지 않는다.
- 트랙은 `gen_track.py`로만 만들고 `validate_track.py`를 통과한 것만 커밋한다.
- 튜닝 값을 바꾸면 `KartCore` 테스트를 돌리고 변경 이유를 커밋 메시지에 쓴다.
- Xcode 빌드와 실기기 확인은 사람이 한다. Claude는 빌드 성공을 가정하지 않는다.

## 15. 리스크와 열린 질문

가장 큰 리스크는 SpatialEventGesture가 양손 동시 핀치를 안정적으로 구분해 주는지이며, 이것은 M1 프로토타입에서 실기기로 가장 먼저 확인한다.

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| SpatialEventGesture가 양손 동시 이벤트를 하나로 합치거나 `inputDevicePose`가 비는 경우 | 조작 체계 전체 | M1에서 확인. 실패 시 ARKit `HandTrackingProvider` + `ImmersiveSpace`로 전환(1장 (c)) |
| 시선이 볼륨 밖(메뉴 윈도우)에 있을 때 핀치가 볼륨에 안 들어옴 | 주행 중 메뉴를 보면 카트가 멈춤 | 주행 중 메뉴 윈도우를 볼륨 뒤로 보내고, HUD는 볼륨 안 attachment로만 둔다 |
| Blender USD 익스포터 버전에 따라 USDZ 직접 내보내기 불가 | 변환 스크립트 | `.usdc` → Reality Converter 경로를 스크립트에 함께 둔다 |
| 최근접 샘플링이 Shader Graph 재질에는 적용 안 됨 | 미니맵 지형 픽셀 룩 | 미니맵 지형은 보간 허용. 카트·타일만 `PhysicallyBasedMaterial` 유지 |
| 타일 `clone` 수가 많아 드로 콜 초과 | 프레임 | 타일을 Blender MCP에서 트랙 단위로 병합한 USDZ 생성 옵션(`--merge-track`) 추가 |
| 체크포인트 트리거를 빠른 속도에 건너뜀 | 랩 미인정 | 트리거 두께를 `maxSpeed / 90 × 2` 이상으로 두고 `path` 인덱스 진행으로 2차 판정 |

**열린 질문 (결정되면 `Docs/decisions.md`에 기록)**

- [ ] M1 결과에 따라 입력 방식 확정 (SpatialEventGesture 유지 vs ARKit)
- [ ] 디버그 튜닝 슬라이더를 릴리스에도 "설정"으로 남길지
- [ ] 트랙 3개의 격자 크기를 모두 8×6으로 할지, 난이도별로 키울지
- [ ] 효과음 파일 포맷(`.wav` vs `.caf`)과 제작 주체
</content>
