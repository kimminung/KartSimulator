import Foundation

/// 엔진음 재생 단위. 파일명·루프 여부는 `Assets/sfx/ENGINE.md` 1장 표 그대로.
public enum EngineVoice: CaseIterable, Hashable, Sendable {
    case ignition, idle, accel, loop, decel

    public var file: String {
        switch self {
        case .ignition: return "engineIgnition"
        case .idle: return "engineIdle"
        case .accel: return "engineAccel"
        case .loop: return "engineLoop"
        case .decel: return "engineDecel"
        }
    }

    public var loops: Bool { self == .idle || self == .loop }
}

/// `EngineSoundMachine`은 "무엇을 재생해야 하는지"만 값으로 내놓는다. 실제 재생(RealityKit)은
/// 앱 레이어의 어댑터가 이 명령을 그대로 실행한다 — 그래야 상태 기계를 RealityKit 없이 테스트할 수 있다.
public enum EngineCommand: Equatable, Sendable {
    case play(EngineVoice, rate: Double, gainDb: Double, fadeIn: Double)
    case stop(EngineVoice, fadeOut: Double)
    case set(EngineVoice, rate: Double, gainDb: Double?)
}

public struct EngineTuning: Sendable {
    public var rateAtStop = 0.70
    public var rateAtFull = 1.00
    public var gainSpanDb = 6.0
    public var smoothing = 0.12
    public var holdMinSpeed = 0.3
    public var accelHandoff = 2.6
    public var handoffFade = 0.13
    public var decelToIdle = 2.2
    public var brakeCutBefore = 1.8
    public var ignitionToIdle = 2.2
    public var useIdle = true
    public init() {}
}

/// `Assets/sfx/ENGINE.md` 3장의 상태 기계를 그대로 옮겼다. 원문은 `DriveState`가 `forwardHalf`/
/// `forwardFull` 두 단계였던 시절 기준이라, 지금의 연속 페달(`DriveState.pedal(Float)`)에 맞게
/// `pedal`(0...1, 방향 무관 — 엔진 회전수는 전진/후진을 구분하지 않는다)과 `isHolding`(회전 중 속도
/// 유지)을 직접 받는 형태로 바꿨다. 나머지 전환 규칙·타이밍은 문서 그대로다.
public struct EngineSoundMachine: Sendable {
    public enum Phase: Equatable, Sendable { case off, ignition, idle, accel, going, decel }

    public private(set) var phase: Phase = .off
    public var tuning = EngineTuning()

    private var rS = 0.0
    private var clipTime = 0.0
    private var clipRate = 1.0
    private var clipGain = 0.0
    private var loopFadeLeft = 0.0
    private var idleOn = false
    private var endAfterDecel = false
    private var isPaused = false

    public init() {}

    private func rate(_ r: Double) -> Double { tuning.rateAtStop + (tuning.rateAtFull - tuning.rateAtStop) * r }
    private func gain(_ r: Double) -> Double { -tuning.gainSpanDb * (1 - r) }

    @discardableResult
    public mutating func update(dt: Double, pedal: Double, isHolding: Bool, speed: Double, maxSpeed: Double) -> [EngineCommand] {
        if isPaused { return [] }
        let r = min(max(abs(speed) / max(maxSpeed, 0.001), 0), 1)
        rS += (r - rS) * (1 - exp(-dt / tuning.smoothing))
        let throttle = pedal > 0.02
        let hold = isHolding && abs(speed) >= tuning.holdMinSpeed
        let target = throttle ? min(max(pedal, 0), 1) : rS

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

    public mutating func resumed(pedal: Double, isHolding: Bool, speed: Double) -> [EngineCommand] {
        isPaused = false
        let moving = (pedal > 0.02 || isHolding) && abs(speed) >= tuning.holdMinSpeed
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
