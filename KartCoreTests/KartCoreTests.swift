import Testing
import Foundation
@testable import KartSimulator

struct HandInputResolverTests {
    // MARK: - 디오라마(기본): 양손 핀치 = 전·후진(상대 거리), 한손만 = 회전 (결정 39)

    @Test func dioramaBothHandsReleasedIsStopped() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0))
        let result = resolver.resolve(now: 0, mode: .diorama)
        #expect(result.drive == .stopped)
    }

    @Test func dioramaLeftOnlyPinchIsTurnLeft() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .left, at: 0, debounced: true)
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.1, mode: .diorama)
        #expect(result.drive == .turnLeft)
    }

    @Test func dioramaRightOnlyPinchIsTurnRight() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .right, at: 0, debounced: true)
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.1, mode: .diorama)
        #expect(result.drive == .turnRight)
    }

    // 전진은 "양손 핀치 유지"(핀치 시작 지점 대비 상대 거리가 기준), 후진은 "핀치한 채로 벌리기"다.
    // 절대 거리(예전의 40cm 피벗)가 아니라 핀치를 시작한 순간의 거리를 기준점으로 삼는다(결정 39).

    @Test func holdingAtPinchStartDistanceIsForward() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        let first = resolver.resolve(now: 0.1, mode: .diorama)
        #expect(pedalValue(first.drive) == 1.0)
        // 같은 거리를 계속 유지해도 전진이 유지돼야 한다.
        feedBothHands(resolver, distance: 0.30, timestamp: 0.1)
        let second = resolver.resolve(now: 0.2, mode: .diorama)
        #expect(pedalValue(second.drive) == 1.0)
    }

    @Test func movingHandsCloserAfterPinchIsStillForward() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .diorama) // 기준점 = 0.30
        feedBothHands(resolver, distance: 0.10, timestamp: 0.1) // 기준점보다 더 좁힘
        let result = resolver.resolve(now: 0.2, mode: .diorama)
        #expect(pedalValue(result.drive) == 1.0, "기준점보다 더 좁히는 것도 전진이어야 한다")
    }

    @Test func draggingApartPastDeadbandEventuallyReverses() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .diorama) // 기준점 = 0.30
        var lastPedal: Float = 1.0
        for frame in 1...40 {
            let t = 0.1 + Double(frame) * (1.0 / 60.0)
            feedBothHands(resolver, distance: 0.30 + 0.04 + 0.20, timestamp: t) // 기준점 + 데드밴드 + 0.20 드래그
            lastPedal = pedalValue(resolver.resolve(now: t + 0.001, mode: .diorama).drive) ?? 0
        }
        #expect(lastPedal < -0.5, "충분히 벌리고 시간이 지나면 후진이 걸려야 한다")
    }

    @Test func draggingFurtherApartIncreasesReverseMagnitude() {
        func pedalAfterDrag(_ drag: Float) -> Float {
            let resolver = HandInputResolver()
            feedBothHands(resolver, distance: 0.30)
            _ = resolver.resolve(now: 0.1, mode: .diorama)
            var pedal: Float = 1.0
            for frame in 1...40 {
                let t = 0.1 + Double(frame) * (1.0 / 60.0)
                feedBothHands(resolver, distance: 0.30 + drag, timestamp: t)
                pedal = pedalValue(resolver.resolve(now: t + 0.001, mode: .diorama).drive) ?? 0
            }
            return pedal
        }
        let smallDrag = pedalAfterDrag(0.04 + 0.05)
        let bigDrag = pedalAfterDrag(0.04 + 0.20)
        #expect(smallDrag < 0 && bigDrag < 0)
        #expect(bigDrag < smallDrag, "더 많이 벌릴수록 후진이 더 세야 한다")
    }

    @Test func dragAtFullReverseSpanIsMaxReverse() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .diorama)
        var pedal: Float = 1.0
        for frame in 1...60 {
            let t = 0.1 + Double(frame) * (1.0 / 60.0)
            feedBothHands(resolver, distance: 0.30 + 0.04 + 0.25, timestamp: t) // 데드밴드 + reverseDragSpan 정확히
            pedal = pedalValue(resolver.resolve(now: t + 0.001, mode: .diorama).drive) ?? 0
        }
        #expect(abs(pedal - (-1.0)) < 0.01)
    }

    @Test func dragBeyondReverseSpanClampsInsteadOfOvershooting() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .diorama)
        var pedal: Float = 1.0
        for frame in 1...60 {
            let t = 0.1 + Double(frame) * (1.0 / 60.0)
            feedBothHands(resolver, distance: 0.30 + 1.0, timestamp: t) // 범위를 한참 넘김
            pedal = pedalValue(resolver.resolve(now: t + 0.001, mode: .diorama).drive) ?? 0
        }
        #expect(abs(pedal - (-1.0)) < 0.01, "-1보다 더 내려가지(overshoot) 않아야 한다")
    }

    @Test func releasingAndRepinchingResetsBaseline() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .diorama) // 기준점 0.30
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0.2))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.2))
        // releaseGrace(120ms)가 지난 뒤에 확인해야 실제로 "뗀" 상태로 판정된다 — 그래야 기준점이 지워진다.
        let releasedResult = resolver.resolve(now: 0.35, mode: .diorama)
        #expect(releasedResult.drive == .stopped)
        // 새 거리(0.60)에서 다시 양손을 핀치 — 이 지점이 새 기준점이 돼야 한다.
        feedBothHands(resolver, distance: 0.60, timestamp: 0.4)
        let result = resolver.resolve(now: 0.5, mode: .diorama)
        #expect(pedalValue(result.drive) == 1.0, "다시 핀치한 지점이 새 기준점이라 전진이어야 한다")
    }

    @Test func distanceSmoothingDelaysReachingFullReverse() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .diorama) // 기준점 0.30
        feedBothHands(resolver, distance: 0.30 + 0.04 + 0.25, timestamp: 0.1) // 최대 후진 지점으로 점프
        let justAfterJump = pedalValue(resolver.resolve(now: 0.15, mode: .diorama).drive) ?? 0
        #expect(justAfterJump > -1.0, "EMA 스무딩 때문에 한 프레임만에 최대 후진까지 가지는 않아야 한다")
    }

    private func pedalValue(_ drive: DriveState) -> Float? {
        if case .pedal(let value) = drive { return value }
        return nil
    }

    // MARK: - 3인칭: 디오라마와 같은 손 모양이지만 후진이 없다 — 양손 핀치는 항상 전진 최대치 (결정 39)

    @Test func thirdPersonBothHandsIsForwardRegardlessOfDistance() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.80) // 디오라마라면 후진일 큰 거리
        let result = resolver.resolve(now: 0.1, mode: .thirdPerson)
        #expect(result.drive == .pedal(1.0), "3인칭은 거리와 무관하게 항상 전진 최대치여야 한다(후진 없음)")
    }

    @Test func thirdPersonOneHandTurns() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .left, at: 0, debounced: true)
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.1, mode: .thirdPerson)
        #expect(result.drive == .turnLeft)
    }

    @Test func thirdPersonNeitherHandIsStopped() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0))
        let result = resolver.resolve(now: 0, mode: .thirdPerson)
        #expect(result.drive == .stopped)
    }

    // MARK: - 1인칭: 손은 가속 여부만, 조향은 머리 방향(ImmersiveBoxView가 따로 계산) (결정 39)

    @Test func firstPersonEitherHandPinchingAccelerates() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .left, at: 0, debounced: true)
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.1, mode: .firstPerson)
        #expect(result.drive == .headSteered(accelerating: true))
    }

    @Test func firstPersonNoHandsStopsAccelerating() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0))
        let result = resolver.resolve(now: 0, mode: .firstPerson)
        #expect(result.drive == .headSteered(accelerating: false))
    }

    // MARK: - 손별 디바운스/그레이스/스테일 (모드와 무관한 공통 로직)

    @Test func pinchBelowDebounceDoesNotCountYet() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0))
        // Only 10ms held, debounce requires 40ms by default.
        let result = resolver.resolve(now: 0.010, mode: .diorama)
        #expect(result.drive == .stopped)
    }

    @Test func releaseWithinGraceStillCountsAsPinching() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .left, at: 0, debounced: true)
        feedPinch(resolver, .right, at: 0, debounced: true)
        // Right hand releases, but within the 120ms grace window.
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.15, mode: .diorama)
        #expect(result.drive != .turnLeft, "release grace should still count the right hand as pinching")
    }

    @Test func staleHandIsReportedUntracked() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: true, position: nil, timestamp: 0))
        // No further events for the right hand past staleTimeout (300ms default).
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: nil, timestamp: 0.5))
        let result = resolver.resolve(now: 0.5, mode: .diorama)
        #expect(result.right.tracked == false)
    }

    private func feedPinch(_ resolver: HandInputResolver, _ chirality: HandChirality, at timestamp: TimeInterval, debounced: Bool) {
        resolver.ingest(HandSample(chirality: chirality, isPinching: true, position: nil, timestamp: timestamp))
        if debounced {
            resolver.ingest(HandSample(chirality: chirality, isPinching: true, position: nil, timestamp: timestamp + 0.05))
        }
    }

    private func feedBothHands(_ resolver: HandInputResolver, distance: Float, timestamp: TimeInterval = 0) {
        let left = SIMD3<Float>(-distance / 2, 0, 0)
        let right = SIMD3<Float>(distance / 2, 0, 0)
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: left, timestamp: timestamp))
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: left, timestamp: timestamp + 0.05))
        resolver.ingest(HandSample(chirality: .right, isPinching: true, position: right, timestamp: timestamp))
        resolver.ingest(HandSample(chirality: .right, isPinching: true, position: right, timestamp: timestamp + 0.05))
    }
}

struct KartMotionStateTests {
    @Test func acceleratesTowardMaxSpeedOverOneSecond() {
        let tuning = MotionTuning()
        var state = KartMotionState()
        for _ in 0..<60 {
            state = state.advancing(drive: .pedal(1.0), tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        // accel = 3.0 m/s^2 over 1s starting from rest -> ~3.0 m/s (below maxSpeed 4.0).
        #expect(abs(state.speed - 3.0) < 0.05)
        #expect(state.position.z < 0, "forward is -Z, so the kart should have moved toward -Z")
    }

    @Test func waitingBrakesFasterThanStopped() {
        let tuning = MotionTuning()
        var waitingState = KartMotionState(speed: 4.0, heading: 0, position: .zero)
        var stoppedState = KartMotionState(speed: 4.0, heading: 0, position: .zero)
        for _ in 0..<30 {
            waitingState = waitingState.advancing(drive: .waiting, tuning: tuning, deltaTime: 1.0 / 60.0)
            stoppedState = stoppedState.advancing(drive: .stopped, tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(waitingState.speed < stoppedState.speed, "brakeDecel should slow the kart faster than coastDecel")
    }

    @Test func turningMaintainsSpeedWithoutInputChange() {
        let tuning = MotionTuning()
        var state = KartMotionState(speed: 2.0, heading: 0, position: .zero)
        for _ in 0..<30 {
            state = state.advancing(drive: .turnLeft, tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(abs(state.speed - 2.0) < 0.001, "turning should neither accelerate nor decelerate the kart")
        #expect(state.heading > 0, "turnLeft should increase heading")
    }

    @Test func turningWhileReversingStillTurns() {
        // 전진 중이든 후진 중이든 회전은 가능해야 한다(음수 속도에서도 회전 조건이 걸려야 함).
        let tuning = MotionTuning()
        var state = KartMotionState(speed: -2.0, heading: 0, position: .zero)
        for _ in 0..<30 {
            state = state.advancing(drive: .turnLeft, tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(abs(state.speed - (-2.0)) < 0.001, "reversing while turning should keep the (negative) speed unchanged")
        #expect(state.heading > 0, "turnLeft should increase heading even while reversing")
    }

    @Test func reverseMovesBackwardAlongHeading() {
        let tuning = MotionTuning()
        var state = KartMotionState()
        for _ in 0..<60 {
            state = state.advancing(drive: .pedal(-1.0), tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(state.speed < 0, "reverse should produce negative speed")
        #expect(state.position.z > 0, "forward is -Z, so reversing should move toward +Z")
    }

    // MARK: - 1인칭: 머리 방향으로 조향(`.headSteered`), 가속은 손 입력만 (결정 39)

    @Test func headSteeredAcceleratingApproachesMaxSpeed() {
        let tuning = MotionTuning()
        var state = KartMotionState()
        for _ in 0..<60 {
            state = state.advancing(drive: .headSteered(accelerating: true), desiredHeading: 0, tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(abs(state.speed - 3.0) < 0.05, "accel 3.0 m/s^2 over 1s from rest -> ~3.0 m/s")
    }

    @Test func headSteeredNotAcceleratingDecelerates() {
        let tuning = MotionTuning()
        var state = KartMotionState(speed: 3.0, heading: 0, position: .zero)
        for _ in 0..<60 {
            state = state.advancing(drive: .headSteered(accelerating: false), desiredHeading: 0, tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(state.speed < 3.0, "손을 떼면 감속해야 한다")
    }

    @Test func headSteeredTurnsTowardDesiredHeadingAtFixedRate() {
        let tuning = MotionTuning(steerRateDegrees: 90)
        var state = KartMotionState(speed: 0, heading: 0, position: .zero)
        // 목표 방향이 90도 떨어져 있고, steerRateDegrees=90°/s라 1초면 정확히 도달해야 한다.
        let desired = Float.pi / 2
        for _ in 0..<60 {
            state = state.advancing(drive: .headSteered(accelerating: false), desiredHeading: desired, tuning: tuning, deltaTime: 1.0 / 60.0)
        }
        #expect(abs(state.heading - desired) < 0.01, "1초 동안 90°/s로 돌면 목표 방향에 도달해야 한다")
    }

    @Test func headSteeredDoesNotOvershootDesiredHeading() {
        let tuning = MotionTuning(steerRateDegrees: 90)
        var state = KartMotionState(speed: 0, heading: 0, position: .zero)
        let desired: Float = 0.1 // steerRateDegrees 기준 한 프레임 최대 회전각보다 훨씬 작은 목표
        state = state.advancing(drive: .headSteered(accelerating: false), desiredHeading: desired, tuning: tuning, deltaTime: 1.0 / 60.0)
        #expect(state.heading <= desired + 0.0001, "목표보다 더 돌아가면(overshoot) 안 된다")
    }

    @Test func headSteeredTurnsShortestDirectionAcrossWrap() {
        let tuning = MotionTuning(steerRateDegrees: 36000) // 한 프레임에 사실상 즉시 도달하도록 아주 크게
        // heading이 +π - 0.01 근처에 있고 목표가 -π + 0.01 근처면, 실제로는 아주 가까운 방향(±π 경계를
        // 넘어서)인데 단순히 desired - heading을 빼면 거의 2π짜리 "먼 길"로 계산된다 — 최단 경로로 가야 한다.
        var state = KartMotionState(speed: 0, heading: .pi - 0.01, position: .zero)
        let desired = -Float.pi + 0.01
        state = state.advancing(drive: .headSteered(accelerating: false), desiredHeading: desired, tuning: tuning, deltaTime: 1.0 / 60.0)
        let shortestDelta = atan2(sin(desired - state.heading), cos(desired - state.heading))
        #expect(abs(shortestDelta) < 0.05, "±π 경계를 최단 방향으로 넘어가야 한다")
    }

    @Test func headSteeredWithNilDesiredHeadingKeepsHeadingUnchanged() {
        let tuning = MotionTuning()
        var state = KartMotionState(speed: 0, heading: 1.0, position: .zero)
        state = state.advancing(drive: .headSteered(accelerating: true), desiredHeading: nil, tuning: tuning, deltaTime: 1.0 / 60.0)
        #expect(state.heading == 1.0, "머리 방향을 못 구했으면(nil) 방향을 바꾸지 않아야 한다")
    }
}

/// `Assets/sfx/ENGINE.md` 5장의 시험 목록 중 핵심 전환만 추린 것. `forwardHalf`/`forwardFull`
/// 대신 연속 페달(`pedal: 1.0` 등)을 쓴다는 점만 문서와 다르다.
struct EngineSoundMachineTests {
    @Test func countdownEndsInIdleAfter2Point2Seconds() {
        var machine = EngineSoundMachine()
        _ = machine.countdownStarted()
        #expect(machine.phase == .ignition)

        var commands: [EngineCommand] = []
        for _ in 0..<132 { // 2.2s / (1/60)
            commands = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: false, speed: 0, maxSpeed: 4.0)
        }
        #expect(machine.phase == .idle)
        #expect(commands.contains { if case .play(.idle, _, _, _) = $0 { true } else { false } })
    }

    @Test func fullThrottleFromIdleHandsOffToLoopAfterAccelHandoff() {
        var machine = EngineSoundMachine()
        _ = machine.countdownStarted()
        for _ in 0..<132 { _ = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: false, speed: 0, maxSpeed: 4.0) }
        #expect(machine.phase == .idle)

        let startCommands = machine.update(dt: 1.0 / 60.0, pedal: 1.0, isHolding: false, speed: 0, maxSpeed: 4.0)
        #expect(machine.phase == .accel)
        #expect(startCommands.contains { if case .play(.accel, _, _, _) = $0 { true } else { false } })

        var sawLoopStart = false
        var speed: Double = 0
        for _ in 0..<200 { // accelHandoff(2.6s)를 넉넉히 넘길 때까지
            speed = min(4.0, speed + (1.0 / 60.0) * 3.0)
            let commands = machine.update(dt: 1.0 / 60.0, pedal: 1.0, isHolding: false, speed: speed, maxSpeed: 4.0)
            if commands.contains(where: { if case .play(.loop, _, _, _) = $0 { true } else { false } }) {
                sawLoopStart = true
                break
            }
        }
        #expect(sawLoopStart, "accel 클립 시간이 accelHandoff(2.6초)를 넘으면 loop로 넘어가야 한다")
        #expect(machine.phase == .going)
    }

    @Test func releasingThrottleWhileGoingStartsDecel() {
        var machine = EngineSoundMachine()
        _ = machine.countdownStarted()
        for _ in 0..<132 { _ = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: false, speed: 0, maxSpeed: 4.0) }
        _ = machine.update(dt: 1.0 / 60.0, pedal: 1.0, isHolding: false, speed: 2.0, maxSpeed: 4.0)
        // 이미 속도가 있는 상태로 시작했으니 clipTime이 금방 accelHandoff를 넘는다.
        var commands: [EngineCommand] = []
        for _ in 0..<60 { commands = machine.update(dt: 1.0 / 60.0, pedal: 1.0, isHolding: false, speed: 3.5, maxSpeed: 4.0) }
        #expect(machine.phase == .going)

        commands = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: false, speed: 3.5, maxSpeed: 4.0)
        #expect(machine.phase == .decel)
        #expect(commands.contains { if case .stop(.loop, _) = $0 { true } else { false } })
        #expect(commands.contains { if case .play(.decel, _, _, _) = $0 { true } else { false } })
    }

    @Test func holdingWhileTurningDoesNotTriggerDecel() {
        var machine = EngineSoundMachine()
        _ = machine.countdownStarted()
        for _ in 0..<132 { _ = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: false, speed: 0, maxSpeed: 4.0) }
        _ = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: true, speed: 2.0, maxSpeed: 4.0)
        #expect(machine.phase == .going, "속도를 유지한 채 회전만 해도(hold) going을 유지해야 한다")

        for _ in 0..<30 {
            _ = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: true, speed: 2.0, maxSpeed: 4.0)
        }
        #expect(machine.phase == .going, "회전 중에는 decel로 빠지면 안 된다")
    }

    @Test func respawnedResetsToIdleWithFadeIn() {
        var machine = EngineSoundMachine()
        _ = machine.countdownStarted()
        for _ in 0..<132 { _ = machine.update(dt: 1.0 / 60.0, pedal: 0, isHolding: false, speed: 0, maxSpeed: 4.0) }
        _ = machine.update(dt: 1.0 / 60.0, pedal: 1.0, isHolding: false, speed: 3.0, maxSpeed: 4.0)
        #expect(machine.phase == .accel)

        let commands = machine.respawned()
        #expect(machine.phase == .idle)
        #expect(commands.contains { if case .play(.idle, _, _, let fadeIn) = $0 { fadeIn == 0.4 } else { false } })
    }
}

private func makeTestTrack(laps: Int = 2, checkpoints: [Int] = [2, 4, 6], pathCount: Int = 8) -> TrackDefinition {
    let path = (0..<pathCount).map { i -> TrackPathPoint in
        let angle = Float(i) / Float(pathCount) * 2 * Float.pi
        return TrackPathPoint(x: cos(angle) * 10, z: sin(angle) * 10)
    }
    return TrackDefinition(
        schemaVersion: 1,
        id: "test_track",
        name: "테스트",
        difficulty: "easy",
        seed: 1,
        laps: laps,
        tileSize: 4.0,
        width: 3.0,
        grid: TrackGrid(cols: 4, rows: 4),
        tiles: [],
        path: path,
        start: TrackStart(pathIndex: 0, heading: 0),
        checkpoints: checkpoints,
        walls: true,
        tuning: nil
    )
}

struct LapTrackerTests {
    @Test func passingAllCheckpointsThenStartIncrementsLap() {
        let tracker = LapTracker(track: makeTestTrack())
        for index in [1, 2, 3, 4, 5, 6, 7, 0] {
            tracker.update(pathIndex: index)
        }
        #expect(tracker.progress.currentLap == 2)
        #expect(tracker.progress.checkpointsPassedThisLap == 0)
    }

    @Test func crossingStartBeforeAllCheckpointsDoesNotCountLap() {
        let tracker = LapTracker(track: makeTestTrack())
        // 체크포인트를 하나도 못 지난 채로 출발선(인덱스 0)을 다시 지나간다.
        for index in [1, 7, 0] {
            tracker.update(pathIndex: index)
        }
        #expect(tracker.progress.currentLap == 1)
    }

    @Test func jumpingAheadStillCreditsCheckpointsPassedAlongTheWay() {
        // path 인덱스 모델에서는 0 -> 4로 바로 가도 중간의 체크포인트(인덱스 2)를 실제로 지나간 것이다.
        let tracker = LapTracker(track: makeTestTrack())
        tracker.update(pathIndex: 4)
        #expect(tracker.progress.checkpointsPassedThisLap == 1)
    }

    @Test func reverseMotionDoesNotCountAsForwardCross() {
        let tracker = LapTracker(track: makeTestTrack())
        tracker.update(pathIndex: 1)
        tracker.update(pathIndex: 2) // 체크포인트 0 통과
        #expect(tracker.progress.checkpointsPassedThisLap == 1)
        tracker.update(pathIndex: 1) // 살짝 후진
        #expect(tracker.progress.checkpointsPassedThisLap == 1, "후진은 크로스로 치지 않는다")
    }

    @Test func finishesAfterConfiguredLapCount() {
        let tracker = LapTracker(track: makeTestTrack(laps: 2))
        let oneLap = [1, 2, 3, 4, 5, 6, 7, 0]
        for index in oneLap { tracker.update(pathIndex: index) }
        #expect(tracker.progress.isFinished == false)
        #expect(tracker.progress.currentLap == 2)
        for index in oneLap { tracker.update(pathIndex: index) }
        #expect(tracker.progress.isFinished == true)
    }

    @Test func resetPositionAvoidsSpuriousCrossOnRespawn() {
        let tracker = LapTracker(track: makeTestTrack())
        tracker.update(pathIndex: 1)
        tracker.resetPosition(pathIndex: 6) // 리스폰으로 순간 이동
        tracker.update(pathIndex: 7)
        #expect(tracker.progress.checkpointsPassedThisLap == 0, "리스폰 점프는 체크포인트 크로스로 치지 않는다")
    }
}

struct TrackPathTests {
    @Test func closestSegmentFindsNearestProjection() {
        let square = TrackPath(points: [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
        ])
        let result = square.closestSegment(to: SIMD2(5, 0.5))
        #expect(result.index == 0)
        #expect(abs(result.distance - 0.5) < 0.001)
    }

    @Test func closestSegmentHandlesCornerProximity() {
        let square = TrackPath(points: [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
        ])
        let result = square.closestSegment(to: SIMD2(10, 10))
        #expect(result.distance < 0.001)
    }
}

struct OffTrackMonitorTests {
    @Test func accumulatesOnlyWhileOffTrack() {
        let monitor = OffTrackMonitor()
        monitor.update(isOffTrack: true, deltaTime: 1.0, threshold: 2.0)
        #expect(monitor.shouldRespawn == false)
        monitor.update(isOffTrack: false, deltaTime: 1.0, threshold: 2.0)
        monitor.update(isOffTrack: true, deltaTime: 1.5, threshold: 2.0)
        #expect(monitor.shouldRespawn == false, "트랙에 복귀하면 타이머가 리셋되어야 한다")
        monitor.update(isOffTrack: true, deltaTime: 0.6, threshold: 2.0)
        #expect(monitor.shouldRespawn == true)
    }

    @Test func acknowledgeRespawnResetsTimer() {
        let monitor = OffTrackMonitor()
        monitor.update(isOffTrack: true, deltaTime: 3.0, threshold: 2.0)
        #expect(monitor.shouldRespawn == true)
        monitor.acknowledgeRespawn()
        #expect(monitor.shouldRespawn == false)
    }
}
