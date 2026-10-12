# 엔진음 사용 설명 (결정 20-6)

RetireX Online이 실제로 쓰는 카트 엔진음과 그 재생 규칙을 핀치 카트의 조작에 맞게 옮긴 것이다. 2026-10-11 개정(결정 54): 조작이 2단계 전진(`forwardHalf`/`forwardFull`)에서 **연속 페달 `DriveState.pedal(Float)`**(결정 30·31·39)로 바뀌고 1인칭이 폐기(결정 47)되어, 3-1장 입력 해석을 테크 구현(`EngineSoundMachine.update(dt:pedal:isHolding:speed:maxSpeed:)`)에 맞췄다. 디오라마·3인칭 모두 같은 규칙이다. 테크가 이 문서만 보고 Swift로 구현할 수 있게 썼다. 파일 출처와 라이선스는 `LICENSES.md` 2장에 있다. 운영자 확인 완료: CC0 기반, 라이선스 제약 없음(2026-10-11).

## 1. 파일

44.1 kHz, 16비트, 모노 `.wav`이고, `node Design/tools/engine.mjs`로 다시 만든다. 5개에 같은 이득을 걸어 가장 큰 피크(`engineLoop`)를 −12 dBFS에 맞췄다. 그래서 **파일끼리의 음량 차이는 원래 설계 그대로**다. 가속 클립 끝(−12 dB RMS)과 루프(−12~−13 dB), 루프와 감속 클립 시작(−13 dB)이 원본에서처럼 이어진다(원본 기준 100 ms RMS).

| 파일 | 길이 | 루프 | 역할 | 소리 높이(기본 주파수) | RMS |
| --- | --- | --- | --- | --- | --- |
| `engineIgnition.wav` | 2.555초 | 아니오 | 시동. 카운트다운 시작에 한 번 | — | −32.9 dB |
| `engineAccel.wav` | 2.731초 | 아니오 | 가속 시작(회전수가 오름) | 44 → 66 Hz(끝이 루프 높이) | −27.7 dB |
| `engineLoop.wav` | 3.016초 | **예** | 주행. 속도에 따라 피치·볼륨이 바뀜 | 32/64 Hz 일정 | −24.1 dB |
| `engineDecel.wav` | 2.539초 | 아니오 | 감속(회전수가 내려감) | 63 → 약 40 Hz | −30.6 dB |
| `engineIdle.wav` | 0.826초 | **예** | 정지 상태 공회전(선택) | 50 Hz 일정 | −38.6 dB |

**루프 지점**: 두 루프 모두 파일 전체가 한 바퀴다(0번 샘플 ~ 마지막 샘플). 루프 시작·끝 표시가 필요 없고 `shouldLoop`만 켜면 된다.

- `engineLoop`은 원본 `car_move_going.wav`의 1.3700~4.3861초 구간이다. 마지막 0.1초는 1.2700~1.3700초와 등전력 교차 페이드로 이었다.
- `engineIdle`은 원본 `car_engine_waiting.wav`의 0.1901~1.0157초 구간이다. 마지막 0.08초는 0.1101~0.1901초와 교차 페이드로 이었다.
- 이음매 검사 결과는 다음과 같다(도구가 매번 출력한다).
  - 이음매의 샘플 계단: 루프 안 큰 계단(상위 1 %)의 0.13배(`engineLoop`), 0.30배(`engineIdle`)다. 수치로는 딸깍 소리가 날 크기가 아니다.
  - 이음매 앞뒤 50 ms 음량 차: 0.6 dB, 0.9 dB다. 루프 안에서 엔진 자체가 흔들리는 폭 안이다(81번째 백분위).
  - 이음매를 걸친 창의 기본 주파수가 앞뒤와 같다(64/50 Hz). 음 높이가 튀지 않는다.
- RetireX는 옛 1초 루프(`lemon_engine_loop.ogg`, 2.0~3.1초 구간)를 "인위적"이라며 원본 클립을 그대로 다시 트는 방식으로 바꿨다(출처 기록). 그래서 이번 루프는 3초로 늘렸다.
- **아직 사람이 들어 보지 않았다.** 위 값은 모두 측정치다. `Design/audio/engine_preview.wav`(6장)로 실제 소리를 확인한다.

## 2. RetireX 방식 (참고)

RetireX는 20틱/초 서버에서 클립 세 개를 상태 기계로 잇는다(`engine_audio.go`, `effects.go`).

| 상태 | 들어가는 때 | 하는 일 | 다음 |
| --- | --- | --- | --- |
| idle | — | 소리 없음 | 가속 입력 → starting |
| starting | 가속 입력 | `start` 클립 재생 | 52틱(2.6초) 뒤 going. start 클립은 끝까지 두고, 남은 0.13초가 교차 페이드 역할을 한다. 그 전에 입력을 떼면 start를 끊고 ending |
| going | starting 2.6초 뒤 | `going` 클립(6.016초) 재생, 110틱(5.5초)마다 다시 재생(0.5초 겹침) | 입력을 떼면 going을 끊고 ending |
| ending | 가속 입력을 뗌 | `end` 클립 재생 | 60틱(3.0초) 뒤 idle. 그 사이 다시 누르면 꼬리 위에 starting |

- 속도 단계: `tier = ceil(5 × 속도/최고속도)`, 1~5. 단계별 음량은 0.25 / 0.30 / 0.35 / 0.40 / 0.45이고, 여기에 재생 음량 `0.55 + 1.15 × 속도비`를 곱한다. **피치는 1로 고정**이다. 같은 녹음을 단계마다 음량만 바꿔 쓴다.
- 그 전 방식은 1초 루프 하나를 5단계로 돌렸다. 피치는 0.78 / 0.90 / 1.02 / 1.14 / 1.26, 음량은 0.11 / 0.14 / 0.17 / 0.20 / 0.23이었다. 음량 폭은 두 방식 모두 약 6 dB(0.11→0.23은 −6.4 dB)다.
- 부스터·드리프트 중이거나 운전자가 없으면 엔진음을 끈다. 핀치 카트에는 이런 상황이 없다.

## 3. 핀치 카트 규칙

### 3-1. 입력 해석 (`DriveState` → 엔진)

| `DriveState` | 엔진 입력 (`pedal`, `isHolding`) | 엔진에게는 | 이유 |
| --- | --- | --- | --- |
| `pedal(v)`, v > 0 (전진) | `pedal = v` | **가속**(throttle), 목표 속도비 = v | 디오라마는 핀치를 유지하면 v = 1.0 |
| `pedal(v)`, v < 0 (후진) | `pedal = abs(v)` | **가속**, 목표 속도비 = abs(v) | 엔진 회전수는 방향과 무관하다. 후진도 같은 가속음 |
| `pedal(0)` | `pedal = 0` | **뗌** | 페달이 0이면 엔진은 놓은 것과 같다 |
| `turnLeft`, `turnRight` | `isHolding = true` | **유지**(hold), 속도가 0.3 m/s(`holdMinSpeed`) 이상일 때만 | 회전 중에는 속도가 유지되므로 감속음을 내면 안 맞다 |
| `stopped`, `waiting` | `pedal = 0`, `isHolding = false` | **뗌**(release) | 자연 감속 / 제동 |

- 가속 판정은 `pedal > 0.02`다. 디오라마·3인칭에서 전진은 거의 항상 1.0이라, 실제로는 "핀치 = 최대 회전수, 놓음 = 감속"으로 들린다.
- 1인칭(`headSteered`)은 폐기됐다(결정 47). 남아 있는 동안에는 `accelerating`을 `pedal = 1` 또는 0으로 넘긴다.

카운트다운 중과 완주 뒤에는 입력을 `stopped`로 넘긴다(카트가 움직이지 않으므로).

### 3-2. 속도 → 피치·볼륨

`r = clamp(speed / maxSpeed, 0, 1)`이다. `maxSpeed`는 기본 4.0 m/s이고 트랙 JSON `tuning`이 덮어쓸 수 있다. `speedKmh`로 쓰면 `r = speedKmh / (maxSpeed × 3.6)`이다. 값이 떨리지 않게 시간 상수 0.12초로 거른다: `rS += (r − rS) × (1 − e^(−dt/0.12))`.

| | 식 | 정지(r=0) | 절반(0.5, 7.2 km/h) | 최대(1.0, 14.4 km/h) |
| --- | --- | --- | --- | --- |
| 재생 속도(=피치) | `0.70 + 0.30 × r` | 0.70 | 0.85 | 1.00 |

(표의 "절반"은 속도 예시다. 입력 단계가 아니다. `r`은 실제 속도에서 구한다.)
| 루프 음량 | `−6 dB × (1 − r)` | −6 dB | −3 dB | 0 dB |

- 녹음 원래 높이가 **최대 속도**다. 가속 클립은 루프 높이에서 끝나고, 감속 클립은 루프 높이에서 시작한다. 그래서 최대 속도에서는 클립과 루프가 같은 피치(1.00)로 이어진다.
- 0.70은 가속 클립이 시작하는 높이(44 Hz ≈ 루프의 0.69배)다. 그래서 낮은 속도에서도 녹음에 있던 회전수 범위를 벗어나지 않는다.
- RetireX(현재)는 피치를 바꾸지 않는다. 핀치 카트는 한 화면에서 카트 하나를 가까이 보므로, 속도감을 피치로 준다. 옛 RetireX 방식(0.78~1.26)과 같은 생각이고, 범위만 녹음에 맞췄다.
- 재생 속도는 높이와 빠르기를 함께 바꾼다(varispeed). RetireX/Bedrock의 pitch와 같다.

### 3-3. 상태 전환

상태는 `off`, `ignition`, `idle`, `accel`, `going`, `decel`이다. RetireX의 idle·starting·going·ending에 시동·꺼짐을 더했다. "클립 시간"은 재생 속도를 곱해 센 시간이다(`clipTime += dt × rate`). 피치를 낮추면 클립도 길어지기 때문이다.

| 지금 | 일 | 할 것 | 다음 |
| --- | --- | --- | --- |
| off | 카운트다운 시작 | `engineIgnition` 재생 | ignition |
| ignition | 2.2초 지남(부동소수점 누적 대비 1e-6 여유, 테크 결정 49) | `engineIdle` 0.3초 페이드 인(시동 꼬리 위로) | idle |
| idle | 가속 | idle 0.3초 페이드 아웃, `engineAccel` 처음부터(피치·음량은 목표 속도비 기준) | accel |
| idle | 유지(회전, 0.3 m/s 이상) | `engineLoop` 0.25초 페이드 인 | going |
| accel | 클립 시간 2.6초 | `engineLoop` 0.13초 페이드 인. **accel은 끄지 않는다**(꼬리가 교차 페이드) | going |
| accel | 이미 빠름: rS ≥ 0.85(`fastHandoffSpeedRatio`)이고 클립 시간 0.5초(`fastHandoffMinClipTime`) 이상 | 2.6초를 기다리지 않고 `engineLoop` 0.13초 페이드 인(테크 결정 49). 가속 클립은 회전수가 올라가는 소리라, 이미 최고 속도 근처면 음이 어긋난다 | going |
| accel | 목표 속도비(페달 값)가 바뀜 | accel 피치·음량을 새 목표 쪽으로 0.3초에 걸쳐 옮김 | accel |
| accel | 뗌 | accel 0.08초 페이드 아웃, `engineDecel` 재생(피치·음량은 지금 rS 기준, 이후 고정) | decel |
| going | 매 프레임 | 루프 피치·음량 = 3-2의 식(rS) | going |
| going | 뗌 | loop 0.08초 페이드 아웃, `engineDecel` 재생 | decel |
| decel | 가속, rS < 0.5 | decel 0.25초 페이드 아웃, `engineAccel` 재생(RetireX의 다시 누르기) | accel |
| decel | 가속, rS ≥ 0.5 / 유지 | decel 0.25초 페이드 아웃, `engineLoop` 0.25초 페이드 인 | going |
| decel | rS < 0.02이고 클립 시간 0.5~1.8초 | 제동으로 일찍 섰다: decel 0.4초 페이드 아웃, idle 페이드 인 | idle |
| decel | 클립 시간 2.2초 | idle 0.3초 페이드 인(decel 꼬리는 그대로 끝남) | idle |

- `useIdle = false`면 idle 소리를 내지 않는다. RetireX처럼 정지 중에는 조용해진다. 기본은 켬을 권한다. 카운트다운 동안 엔진이 켜져 있다는 느낌을 준다.
- RetireX에서 바꾼 점은 다음과 같다.
  - **주행 루프:** RetireX는 6초 클립을 5.5초마다 다시 틀지만, 여기서는 이음매 없는 루프 하나로 대신한다.
  - **빠를 때 다시 누르기:** 속도가 이미 절반 이상이면 낮은 회전수에서 시작하는 가속 클립을 건너뛰고 루프로 바로 간다.
  - **제동:** 제동으로 일찍 서면 2.5초짜리 감속음을 줄인다. 핀치 카트의 `waiting` 제동은 5 m/s²라 최대 속도에서 0.8초 만에 선다.

### 3-4. 레이스 이벤트

| 이벤트 | 할 것 |
| --- | --- |
| 카운트다운 시작(`countdownTick` 3) | `off → ignition`. 시동 2.555초가 3·2·1 사이에 끝나고 idle로 넘어간다 |
| GO | 엔진에게는 아무 일도 없다. 플레이어가 핀치하면 3-3대로 |
| 일시정지 | 모든 엔진 소리 0.15초 페이드 아웃. 재개 전까지 `update`는 명령을 내지 않는다 |
| 재개 | 가속·유지 중이고 0.3 m/s 이상이면 루프 0.2초 페이드 인(going). 아니면 idle 페이드 인 |
| 벽 접촉(`wallBump`) | 엔진에는 따로 없다. 속도가 `wallSpeedKeep`(0.5)배로 줄면 rS 거르기로 피치가 0.12초 동안 내려간다(회전수가 꺾이는 소리) |
| 리스폰(`respawn`) | 모든 엔진 소리 0.05초 안에 끔 → idle(리스폰 효과음 뒤 0.4초 페이드 인) |
| 완주(`finish`) | accel·going이면 decel로. decel이 끝나면 idle을 켜지 않고 off(결과 화면은 조용하게) |
| 트랙 선택·종료 | 모든 엔진 소리 0.1초 페이드 아웃, off |

### 3-5. 음량 배치

- 엔진 소리는 모두 **엔진 버스 −6 dB**를 거친다. 효과음 7개(피크 −12 dBFS)가 엔진 위로 또렷이 들리게 하려는 것이다. 최종 게인은 `−6 + 3-2의 음량`이다. 시동·idle·가속·감속은 파일 음량 그대로 −6 dB만 건다. 가속·감속은 목표나 놓은 순간의 루프 음량도 더한다.
- 소리는 카트 엔티티에서 나게 한다(공간 음향). 테이블 위 카트가 왼쪽에 있으면 엔진음도 왼쪽에서 들린다.
- 동시에 나는 엔진 소리는 최대 3개다(accel 꼬리 + loop, decel 꼬리 + accel + idle 페이드).

## 4. Swift 구현 스케치

> 이 스케치는 2단계 전진 시절의 초판이다. 실제 구현은 `KartSimulator/KartCore/EngineSoundMachine.swift`(입력 `pedal`·`isHolding`, 3-1장)이며, 그쪽이 기준이다.

엔진 상태 기계는 `KartCore`의 순수 값 타입으로 두면 테스트할 수 있다. 재생은 RealityKit 어댑터가 맡는다. API 이름(`AudioFileResource` 초기화, `AudioPlaybackController.speed`/`gain`/`fade`)은 visionOS SDK 버전에 따라 다를 수 있으니 Xcode에서 확인한다. `speed`가 없거나 피치가 안 바뀌면 `AVAudioEngine` + `AVAudioUnitVarispeed`로 같은 명령을 실행한다.

```swift
// KartCore/EngineSoundMachine.swift
import Foundation

public enum EngineVoice: CaseIterable, Hashable {
    case ignition, idle, accel, loop, decel
    public var file: String {
        switch self {
        case .ignition: "engineIgnition"; case .idle: "engineIdle"; case .accel: "engineAccel"
        case .loop: "engineLoop"; case .decel: "engineDecel"
        }
    }
    public var loops: Bool { self == .idle || self == .loop }
}

public enum EngineCommand: Equatable {
    case play(EngineVoice, rate: Double, gainDb: Double, fadeIn: Double)   // 파일 처음부터
    case stop(EngineVoice, fadeOut: Double)
    case set(EngineVoice, rate: Double, gainDb: Double?)                     // nil: 페이드 중이라 음량은 그대로
}

public struct EngineTuning {
    public var rateAtStop = 0.70, rateAtFull = 1.00
    public var gainSpanDb = 6.0
    public var smoothing = 0.12          // s
    public var holdMinSpeed = 0.3        // m/s (MotionTuning.minTurnSpeed)
    public var accelHandoff = 2.6        // 클립 초 (RetireX 52틱)
    public var handoffFade = 0.13
    public var decelToIdle = 2.2         // 클립 초
    public var brakeCutBefore = 1.8      // 클립 초: 이보다 일찍 서면 감속음을 줄임(자연 감속은 2.0초에 섬)
    public var ignitionToIdle = 2.2      // s
    public var useIdle = true
    public init() {}
}

public struct EngineSoundMachine {
    public enum Phase: Equatable { case off, ignition, idle, accel, going, decel }
    public private(set) var phase: Phase = .off
    public var tuning = EngineTuning()
    private var rS = 0.0, clipTime = 0.0, clipRate = 1.0, clipGain = 0.0
    private var loopFadeLeft = 0.0, idleOn = false, endAfterDecel = false, isPaused = false

    public init() {}
    func rate(_ r: Double) -> Double { tuning.rateAtStop + (tuning.rateAtFull - tuning.rateAtStop) * r }
    func gain(_ r: Double) -> Double { -tuning.gainSpanDb * (1 - r) }

    public mutating func update(dt: Double, state: DriveState, speed: Double, maxSpeed: Double) -> [EngineCommand] {
        if isPaused { return [] }
        let r = min(max(abs(speed) / max(maxSpeed, 0.001), 0), 1)
        rS += (r - rS) * (1 - exp(-dt / tuning.smoothing))
        let throttle = state == .forwardHalf || state == .forwardFull
        let hold = (state == .turnLeft || state == .turnRight) && abs(speed) >= tuning.holdMinSpeed
        let target = state == .forwardFull ? 1.0 : state == .forwardHalf ? 0.5 : rS
        var out: [EngineCommand] = []
        switch phase {
        case .off:
            break
        case .ignition:
            clipTime += dt
            if clipTime >= tuning.ignitionToIdle { phase = .idle; out += idleIn(0.3) }
        case .idle:
            if throttle { out += startAccel(target) } else if hold { out += startLoop(fade: 0.25) }
        case .accel:
            clipTime += dt * clipRate
            if !throttle && !hold {
                out.append(.stop(.accel, fadeOut: 0.08)); out += startDecel()
            } else {
                let want = rate(target)
                if abs(want - clipRate) > 0.001 {
                    clipRate += (want - clipRate) * min(1, dt / 0.3)
                    clipGain += (gain(target) - clipGain) * min(1, dt / 0.3)
                    out.append(.set(.accel, rate: clipRate, gainDb: clipGain))
                }
                if clipTime >= tuning.accelHandoff { out += startLoop(fade: tuning.handoffFade) }
            }
        case .going:
            if !throttle && !hold {
                out.append(.stop(.loop, fadeOut: 0.08)); out += startDecel()
            } else {
                loopFadeLeft = max(0, loopFadeLeft - dt)
                out.append(.set(.loop, rate: rate(rS), gainDb: loopFadeLeft > 0 ? nil : gain(rS)))
            }
        case .decel:
            clipTime += dt * clipRate
            if throttle || hold {
                out.append(.stop(.decel, fadeOut: 0.25))
                out += (throttle && rS < 0.5) ? startAccel(target) : startLoop(fade: 0.25)
            } else if clipTime >= tuning.decelToIdle || (rS < 0.02 && clipTime >= 0.5 && clipTime < tuning.brakeCutBefore) {
                if clipTime < tuning.decelToIdle { out.append(.stop(.decel, fadeOut: 0.4)) }
                if endAfterDecel { phase = .off } else { phase = .idle; out += idleIn(0.3) }
            }
        }
        return out
    }

    // 레이스 이벤트
    public mutating func countdownStarted() -> [EngineCommand] {
        phase = .ignition; clipTime = 0; endAfterDecel = false
        return [.play(.ignition, rate: 1, gainDb: 0, fadeIn: 0)]
    }
    public mutating func paused() -> [EngineCommand] {
        isPaused = true; idleOn = false
        return EngineVoice.allCases.map { .stop($0, fadeOut: 0.15) }
    }
    public mutating func resumed(state: DriveState, speed: Double) -> [EngineCommand] {
        isPaused = false
        let moving = [DriveState.forwardHalf, .forwardFull, .turnLeft, .turnRight].contains(state) && abs(speed) >= tuning.holdMinSpeed
        if moving { return startLoop(fade: 0.2) }
        phase = .idle; return idleIn(0.3)
    }
    public mutating func respawned() -> [EngineCommand] {
        idleOn = false; rS = 0; phase = .idle; isPaused = false
        return EngineVoice.allCases.map { .stop($0, fadeOut: 0.05) } + idleIn(0.4)
    }
    public mutating func finished() -> [EngineCommand] {
        endAfterDecel = true
        switch phase {
        case .accel: return [.stop(.accel, fadeOut: 0.08)] + startDecel()
        case .going: return [.stop(.loop, fadeOut: 0.08)] + startDecel()
        case .decel: return []
        default: phase = .off; idleOn = false; return EngineVoice.allCases.map { .stop($0, fadeOut: 1.0) }
        }
    }
    public mutating func stopAll() -> [EngineCommand] {
        phase = .off; idleOn = false; return EngineVoice.allCases.map { .stop($0, fadeOut: 0.1) }
    }

    // 내부
    private mutating func startAccel(_ target: Double) -> [EngineCommand] {
        phase = .accel; clipTime = 0; clipRate = rate(target); clipGain = gain(target)
        return idleOut(0.3) + [.play(.accel, rate: clipRate, gainDb: clipGain, fadeIn: 0.01)]
    }
    private mutating func startLoop(fade: Double) -> [EngineCommand] {
        phase = .going; loopFadeLeft = fade
        return idleOut(0.3) + [.play(.loop, rate: rate(rS), gainDb: gain(rS), fadeIn: fade)]
    }
    private mutating func startDecel() -> [EngineCommand] {
        phase = .decel; clipTime = 0; clipRate = rate(rS); clipGain = gain(rS)
        return [.play(.decel, rate: clipRate, gainDb: clipGain, fadeIn: 0.02)]
    }
    private mutating func idleIn(_ fade: Double) -> [EngineCommand] {
        guard tuning.useIdle, !idleOn else { return [] }
        idleOn = true; return [.play(.idle, rate: 1, gainDb: 0, fadeIn: fade)]
    }
    private mutating func idleOut(_ fade: Double) -> [EngineCommand] {
        guard idleOn else { return [] }
        idleOn = false; return [.stop(.idle, fadeOut: fade)]
    }
}
```

```swift
// RealityKit 어댑터 (예시)
import RealityKit

@MainActor final class EngineAudioPlayer {
    private var controllers: [EngineVoice: AudioPlaybackController] = [:]
    private var generation: [EngineVoice: Int] = [:]
    private let busDb = -6.0
    private let silentDb = -80.0

    init(kart: Entity) async throws {
        kart.components.set(SpatialAudioComponent())
        for v in EngineVoice.allCases {
            let res = try await AudioFileResource(named: v.file + ".wav",
                                                  configuration: .init(shouldLoop: v.loops))
            controllers[v] = kart.prepareAudio(res)
        }
    }

    func run(_ commands: [EngineCommand]) {
        for c in commands {
            switch c {
            case let .play(v, rate, gainDb, fadeIn):
                guard let p = controllers[v] else { continue }
                generation[v, default: 0] += 1
                p.stop(); p.speed = rate
                if fadeIn > 0 { p.gain = silentDb; p.play(); p.fade(to: busDb + gainDb, duration: fadeIn) }
                else { p.gain = busDb + gainDb; p.play() }
            case let .stop(v, fadeOut):
                guard let p = controllers[v], p.isPlaying else { continue }
                let g = generation[v, default: 0]
                p.fade(to: silentDb, duration: fadeOut)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(fadeOut))
                    if self.generation[v] == g { p.stop() }   // 그 사이 다시 재생됐으면 끄지 않음
                }
            case let .set(v, rate, gainDb):
                guard let p = controllers[v] else { continue }
                p.speed = rate
                if let gainDb { p.gain = busDb + gainDb }
            }
        }
    }
}
```

호출 위치는 다음과 같다.
- 매 프레임: `player.run(machine.update(dt:state:speed:maxSpeed:))`
- 이벤트(`RaceEvent.countdownTick` 첫 회, 일시정지·재개, `respawn`, `finish`): 해당 메서드의 결과를 `run`에 넘긴다.

## 5. 시험

**단위 시험**(`KartCoreTests`, 상태 기계만): 아래 각 경우의 명령 순서와 상태를 확인한다.

1. `countdownStarted` → 2.2초 뒤 `.play(.idle)`, 상태 idle.
2. idle에서 `pedal = 1` 유지 → `.stop(.idle)` + `.play(.accel, rate: 1.0)` → 클립 시간 2.6초에 `.play(.loop)`(accel stop 없음) → 이후 매 프레임 `.set(.loop)`.
3. `pedal = 0.5`로 같은 과정 → accel 재생 속도 0.85. 클립 시간 기준이라 실제 2.6/0.85 ≈ 3.06초 뒤에 루프가 시작된다.
4. going 중 `stopped` → `.stop(.loop, 0.08)` + `.play(.decel)` → 2.2초 뒤 idle.
5. going 중 `waiting`(제동, 5 m/s²) → 약 1.0초에 `.stop(.decel, 0.4)` + idle. 자연 감속(`stopped`, 2 m/s²)은 2.0초에 서므로 끊지 않고 2.2초에 idle.
6. decel 중 rS ≥ 0.5에서 다시 `pedal = 1` → `.play(.loop)`(accel 아님). rS < 0.5면 `.play(.accel)`.
7. going 중 `turnLeft`(속도 유지) → 상태 going 그대로, decel 없음.
8. 루프 페이드 인 중(0.13초)에는 `.set(.loop, gainDb: nil)`.
9. `finished` 중 decel이 끝나면 off, idle 재생 없음.
10. `respawned` → 모든 소리 stop + idle 0.4초 페이드 인.

**청취 확인**(실기기):
- 최대 전진: 시동 꺼짐 없이 가속에서 주행으로 넘어가는 순간에 음 높이·음량이 튀지 않는다.
- 3초 넘게 직진해도 루프 반복이 들리지 않는다.
- 페달 값을 바꾸면 피치가 부드럽게 옮겨 간다.
- 효과음(체크포인트·랩)이 엔진음 위로 또렷하다.

## 6. 다시 만들기 · 합성본으로 바꾸기

- 원본에서 다시: `node Design/tools/engine.mjs [XK ENGINE sounds 폴더]`. 원본 SHA-256이 기록과 다르면 멈춘다.
- 미리듣기: `node Design/tools/engine.mjs --preview`(합성본은 `--synth --preview`). 3-2·3-3의 규칙대로 25초를 이어 붙인다: 0초 시동, 2.2초 공회전, 4.0초 최대 가속, 6.6초 주행, 10.6초 뗌, 12.8초 공회전, 14.6초 절반 가속, 17.66초 주행, 20.66초 뗌. 결과는 `Design/audio/engine_preview.wav`, `Design/audio/engine_synth/_preview.wav`다. 엔진 버스 −6 dB는 빼고 만들었다.
- 합성 대체본: `node Design/tools/engine.mjs --synth` → `Design/audio/engine_synth/`. 클립끼리의 음량 비율(루프 대비 RMS)을 원본에 맞췄다: 시동 −8.8, 가속 −3.6, 감속 −6.5, 공회전 −14.5 dB. 라이선스 확인 결과 원본을 공개할 수 없으면 이 5개를 `Assets/sfx/`로 복사한다. 이름·루프 여부·단발 길이(±0.01초)가 같아서 이 문서의 규칙과 코드를 그대로 쓴다.
