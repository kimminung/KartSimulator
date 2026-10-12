import Testing
import Foundation
import simd
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

    // MARK: - 3인칭: 디오라마와 **같은 규칙** — 유지 = 전진, 벌리면 후진, 한손 = 회전 (결정 49, Issue #24)

    @Test func thirdPersonHoldingPinchIsForwardLikeDiorama() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.80)
        let result = resolver.resolve(now: 0.1, mode: .thirdPerson)
        #expect(result.drive == .pedal(1.0), "핀치를 시작한 간격 그대로면(넓게 시작했어도) 전진 최대치")
    }

    @Test func thirdPersonSpreadingAfterPinchReversesLikeDiorama() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        _ = resolver.resolve(now: 0.1, mode: .thirdPerson)
        for i in 1...40 {
            feedBothHands(resolver, distance: 0.30 + 0.40 * Float(i) / 40, timestamp: 0.1 + Double(i) * 0.05)
            _ = resolver.resolve(now: 0.1 + Double(i) * 0.05 + 0.05, mode: .thirdPerson)
        }
        let result = resolver.resolve(now: 2.3, mode: .thirdPerson)
        #expect((pedalValue(result.drive) ?? 1) < 0, "3인칭에도 후진이 있다(디오라마와 같은 규칙)")
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

// MARK: - 카트 정면 보정 (결정 27·29·42): "front" 마커 방향을 주행 수학의 정면 축(로컬 -Z)으로 보낸다

struct KartForwardCorrectionTests {
    private func rotated(_ x: Float, _ z: Float) -> SIMD2<Float>? {
        guard let angle = KartForwardCorrection.angle(noseX: x, noseZ: z) else { return nil }
        return KartForwardCorrection.rotatedXZ(noseX: x, noseZ: z, by: angle)
    }

    private func isMinusZ(_ v: SIMD2<Float>?) -> Bool {
        guard let v else { return false }
        return abs(v.x) < 1e-4 && abs(v.y + 1) < 1e-4
    }

    /// 이 로스터의 실제 상황: `front_aero` 마커가 로컬 +Z(0, 0.24, 1.41)에 있다 → 180도 보정이어야 한다.
    @Test func noseOnPlusZNeedsHalfTurn() {
        let angle = KartForwardCorrection.angle(noseX: 0, noseZ: 1.41)
        #expect(angle != nil)
        #expect(abs(abs(angle!) - .pi) < 1e-4)
        #expect(isMinusZ(rotated(0, 1.41)))
    }

    /// 이미 -Z가 정면인 모델은 보정이 0이어야 한다.
    @Test func noseOnMinusZNeedsNoRotation() {
        let angle = KartForwardCorrection.angle(noseX: 0, noseZ: -2)
        #expect(angle != nil)
        #expect(abs(angle!) < 1e-4)
        #expect(isMinusZ(rotated(0, -2)))
    }

    /// 옆으로 export된 모델(+X / -X 정면)도 -Z로 보내야 한다.
    @Test func noseOnSideAxesEndsUpOnMinusZ() {
        #expect(isMinusZ(rotated(1, 0)))
        #expect(isMinusZ(rotated(-1, 0)))
        #expect(isMinusZ(rotated(0.7, 0.7)))
    }

    /// 보정 뒤의 정면(-Z)은 heading 0일 때 `KartMotionState`가 나아가는 방향과 같아야 한다.
    @Test func correctedNoseMatchesMotionForwardAtHeadingZero() {
        var motion = KartMotionState(speed: 1, heading: 0, position: .zero)
        motion = motion.advancing(drive: .pedal(1.0), tuning: MotionTuning(), deltaTime: 1)
        let moved = SIMD2<Float>(motion.position.x, motion.position.z)
        let nose = rotated(0, 1.41)!
        // 같은 방향(내적 > 0)이고 X 성분은 0
        #expect(moved.y < 0 && abs(moved.x) < 1e-4)
        #expect(nose.x * moved.x + nose.y * moved.y > 0)
    }

    @Test func degenerateNoseReturnsNil() {
        #expect(KartForwardCorrection.angle(noseX: 0, noseZ: 0) == nil)
    }
}

// MARK: - 씬 루트 배치 (Phase 2, 결정 44): world = position + scale · R_y(yaw) · local

struct ScenePlacementTests {
    private func world(_ local: SIMD3<Float>, position: SIMD3<Float>, yaw: Float, scale: Float) -> SIMD3<Float> {
        position + ScenePlacement.rotateY(local, by: yaw) * scale
    }

    private func close(_ a: SIMD3<Float>, _ b: SIMD3<Float>, tol: Float = 1e-4) -> Bool {
        abs(a.x - b.x) < tol && abs(a.y - b.y) < tol && abs(a.z - b.z) < tol
    }

    /// rootPosition으로 구한 position을 쓰면 local이 정확히 target에 놓인다 — 배율·회전이 섞여도.
    @Test func rootPositionPlacesLocalAtTarget() {
        let local = SIMD3<Float>(12, 0, -7)
        let target = SIMD3<Float>(0.3, 0.86, -1.1)
        for (yaw, scale) in [(Float.pi, Float(0.03)), (Float(0.7), Float(1)), (Float(-2.1), Float(0.5))] {
            let p = ScenePlacement.rootPosition(placing: local, at: target, yaw: yaw, scale: scale)
            #expect(close(world(local, position: p, yaw: yaw, scale: scale), target))
        }
    }

    /// rotateY는 KartMotionState/KartForwardCorrection과 같은 관례: R_y(yaw)·forward(h) = forward(h + yaw).
    @Test func rotateYComposesWithHeading() {
        for (h, yaw) in [(Float(0), Float.pi / 2), (Float(1.2), Float(-0.4)), (Float(4.7), Float.pi)] {
            let rotated = ScenePlacement.rotateY(ScenePlacement.forward(heading: h), by: yaw)
            #expect(close(rotated, ScenePlacement.forward(heading: h + yaw)))
        }
    }

    /// 모드에 들어온 순간 출발 heading이 머리 방향을 향해야 한다.
    @Test func sceneYawMakesStartHeadingFaceHead() {
        let start: Float = 4.712389 // track_01
        let headYaw: Float = 0.3
        let yaw = ScenePlacement.sceneYaw(startHeading: start, headYaw: headYaw)
        let worldForward = ScenePlacement.rotateY(ScenePlacement.forward(heading: start), by: yaw)
        #expect(close(worldForward, ScenePlacement.forward(heading: headYaw)))
    }

    /// 3인칭: 카트는 머리 아래 1.8 m, **기준 방향**(진입 순간 머리 yaw)으로 2.5 m 앞. 디오라마는 anchor 그대로.
    @Test func cockpitTargetsPerMode() {
        let tuning = CockpitTuning(thirdPersonEyeAboveFloor: 1.8, thirdPersonKartAhead: 2.5)
        let anchor = SIMD3<Float>(1, 1.5, -2)
        let tp = ScenePlacement.cockpitTarget(anchor: anchor, mode: .thirdPerson, referenceYaw: -2.0, tuning: tuning)
        #expect(close(tp, SIMD3(1, -0.3, -2) + ScenePlacement.forward(heading: -2.0) * 2.5))
        let d = tp - SIMD3(1, -0.3, -2)
        #expect(abs((d.x * d.x + d.z * d.z).squareRoot() - 2.5) < 1e-4 && abs(d.y) < 1e-4)
        #expect(close(ScenePlacement.cockpitTarget(anchor: anchor, mode: .diorama, referenceYaw: 0, tuning: tuning), anchor))
    }

    /// rootPosition + cockpitTarget을 합치면 카트(노면 높이 포함)가 기준 방향 2.5 m 앞·1.8 m 아래에 온다.
    @Test func thirdPersonFollowPutsKartAheadOfReference() {
        let tuning = CockpitTuning()
        let anchor = SIMD3<Float>(0.2, 1.3, -0.4)
        let kart = SIMD3<Float>(18, 0.25, -10)
        let reference: Float = 0.7
        let yaw = ScenePlacement.chaseSceneYaw(kartHeading: 2.0, referenceYaw: reference)
        let target = ScenePlacement.cockpitTarget(anchor: anchor, mode: .thirdPerson, referenceYaw: reference, tuning: tuning)
        let p = ScenePlacement.rootPosition(placing: kart, at: target, yaw: yaw, scale: 1)
        let kartWorld = world(kart, position: p, yaw: yaw, scale: 1)
        #expect(close(kartWorld, anchor - SIMD3(0, tuning.thirdPersonEyeAboveFloor, 0) + ScenePlacement.forward(heading: reference) * tuning.thirdPersonKartAhead))
    }

    /// 카트 크기: 디오라마는 배율로 나눠 시각 크기를 고정, 실제 크기 모드는 전장 그대로.
    @Test func kartFitLengthPerMode() {
        let tuning = CockpitTuning(kartRealLength: 1.5)
        #expect(abs(ScenePlacement.kartFitLength(mode: .diorama, sceneScale: 0.03, dioramaVisualLength: 0.12, tuning: tuning) - 4.0) < 1e-4)
        #expect(ScenePlacement.kartFitLength(mode: .thirdPerson, sceneScale: 1, dioramaVisualLength: 0.12, tuning: tuning) == 1.5)
    }

    /// 3인칭 추적 카메라(결정 46·49): chaseSceneYaw를 씬 yaw로 쓰면 지금 카트 heading의 월드 정면이 기준 방향과 같다
    /// = 사용자는 카트 뒤에서 카트가 가는 쪽을 본다. 평활을 거쳐도 충분히 지나면 같은 곳에 수렴한다.
    @Test func chaseSceneYawPutsViewerBehindKart() {
        let kartHeading: Float = 2.3, headYaw: Float = -0.4
        let yaw = ScenePlacement.chaseSceneYaw(kartHeading: kartHeading, referenceYaw: headYaw)
        let kartWorldForward = ScenePlacement.rotateY(ScenePlacement.forward(heading: kartHeading), by: yaw)
        #expect(close(kartWorldForward, ScenePlacement.forward(heading: headYaw)))

        // 카트가 90° 꺾였을 때 씬 yaw를 평활로 따라가면 1초 뒤(rate 2.5) 약 92 %, 3초 뒤 99.9 % 수렴
        var sceneYaw = yaw
        let turned = kartHeading + .pi / 2
        let target = ScenePlacement.chaseSceneYaw(kartHeading: turned, referenceYaw: headYaw)
        for _ in 0..<90 { sceneYaw = ScenePlacement.approachAngle(from: sceneYaw, to: target, rate: 2.5, deltaTime: 1.0 / 90.0) }
        let remaining = abs(atan2(sin(target - sceneYaw), cos(target - sceneYaw)))
        #expect(remaining < (Float.pi / 2) * 0.1 && remaining > 0)
        for _ in 0..<180 { sceneYaw = ScenePlacement.approachAngle(from: sceneYaw, to: target, rate: 2.5, deltaTime: 1.0 / 90.0) }
        #expect(abs(atan2(sin(target - sceneYaw), cos(target - sceneYaw))) < 0.01)
    }

    /// 머리 yaw 평활: 최단 경로로, rate가 클수록 빨리, ±π 경계를 넘어도 짧은 쪽으로.
    @Test func approachAngleFollowsShortestPathAndRate() {
        // 한 스텝에 (1 - e^-1) ≈ 63 % 따라간다
        let a = ScenePlacement.approachAngle(from: 0, to: 1, rate: 1, deltaTime: 1)
        #expect(abs(a - (1 - exp(Float(-1)))) < 1e-4)
        // rate 0이면 안 움직이고, 아주 큰 rate면 사실상 도달
        #expect(ScenePlacement.approachAngle(from: 0.3, to: 2, rate: 0, deltaTime: 1) == 0.3)
        #expect(abs(ScenePlacement.approachAngle(from: 0.3, to: 2, rate: 1000, deltaTime: 1) - 2) < 1e-3)
        // +170° → -170°는 +20° 방향이 최단: 결과가 180°를 넘어가야 한다(-180° 쪽이 아니라)
        let from = Float(170) * .pi / 180, to = Float(-170) * .pi / 180
        let step = ScenePlacement.approachAngle(from: from, to: to, rate: 1000, deltaTime: 1)
        #expect(abs(atan2(sin(step - to), cos(step - to))) < 1e-3)
        #expect(step > from)
    }
}

// MARK: - 미니맵 투영 (M4, 결정 48)

struct MinimapProjectionTests {
    /// track_01과 비슷한 20 × 12 m 직사각 루프 + 노면 폭 3 m가 지름 0.24 m 테이블에 들어가고 중심이 원점에 온다.
    @Test func fitsTrackInsideTableAndCentersIt() {
        let pts: [SIMD2<Float>] = [SIMD2(6, -6), SIMD2(26, -6), SIMD2(26, -18), SIMD2(6, -18)]
        let p = MinimapProjection(points: pts, trackWidth: 3, tableDiameter: 0.24)
        #expect(abs(p.center.x - 16) < 1e-4 && abs(p.center.y + 12) < 1e-4)
        // 가장 긴 변 20 + 3 = 23 m → 내접 정사각형 0.24/√2 · 0.9
        let expectedScale = Float(0.24) / Float(2).squareRoot() * 0.9 / 23
        #expect(abs(p.scale - expectedScale) < 1e-6)
        for pt in pts {
            let m = p.mapPosition(pt)
            #expect(simd_length(m) + p.mapLength(1.5) <= 0.12 + 1e-5) // 노면 반폭까지 포함해도 원 안
        }
        #expect(simd_length(p.mapPosition(p.center)) < 1e-6)
    }

    @Test func mapLengthUsesSameScale() {
        let p = MinimapProjection(points: [SIMD2(0, 0), SIMD2(10, 0)], trackWidth: 2, tableDiameter: 0.24)
        #expect(abs(p.mapLength(4) - 4 * p.scale) < 1e-7)
    }

    @Test func emptyPathIsIdentity() {
        let p = MinimapProjection(points: [], trackWidth: 3, tableDiameter: 0.24)
        #expect(p.scale == 1 && p.center == .zero)
    }

    /// LapTracker는 순서대로만 통과시키므로 앞에서부터 passedCount개가 통과.
    @Test func checkpointPassedOrdinals() {
        #expect(MinimapProjection.isCheckpointPassed(ordinal: 0, passedCount: 1))
        #expect(!MinimapProjection.isCheckpointPassed(ordinal: 1, passedCount: 1))
        #expect(!MinimapProjection.isCheckpointPassed(ordinal: 0, passedCount: 0))
        #expect(MinimapProjection.isCheckpointPassed(ordinal: 2, passedCount: 3))
    }
}

// MARK: - 3인칭 카메라 기준 방향 (결정 49, Issue #25): 고개 ±45° 자유, ±60° 2초 넘으면 리센터

struct ChaseCameraReferenceTests {
    private let tuning = CockpitTuning(recenterThresholdDegrees: 60, recenterHoldSeconds: 2, recenterRate: 1.0)

    @Test func freeLookDoesNotMoveReference() {
        var ref = ChaseCameraReference(forwardYaw: 0.2)
        for _ in 0..<600 { ref.update(headYaw: 0.2 + 40 * .pi / 180, deltaTime: 1.0 / 60.0, tuning: tuning) } // 40°, 10초
        #expect(abs(ref.forwardYaw - 0.2) < 1e-6 && !ref.isRecentering)
    }

    @Test func briefGlanceBeyondThresholdDoesNotRecenter() {
        var ref = ChaseCameraReference(forwardYaw: 0)
        for _ in 0..<90 { ref.update(headYaw: 80 * .pi / 180, deltaTime: 1.0 / 60.0, tuning: tuning) } // 1.5초 < 2초
        #expect(!ref.isRecentering && ref.forwardYaw == 0)
        ref.update(headYaw: 0, deltaTime: 1.0 / 60.0, tuning: tuning) // 돌아오면 타이머 리셋
        for _ in 0..<90 { ref.update(headYaw: 80 * .pi / 180, deltaTime: 1.0 / 60.0, tuning: tuning) }
        #expect(!ref.isRecentering)
    }

    @Test func holdingBeyondThresholdRecentersTowardHead() {
        var ref = ChaseCameraReference(forwardYaw: 0)
        let head: Float = 90 * .pi / 180
        for _ in 0..<125 { ref.update(headYaw: head, deltaTime: 1.0 / 60.0, tuning: tuning) } // 2.08초
        #expect(ref.isRecentering)
        for _ in 0..<60 { ref.update(headYaw: head, deltaTime: 1.0 / 60.0, tuning: tuning) } // 1초: 약 63 %
        #expect(ref.forwardYaw > head * 0.5 && ref.forwardYaw < head)
        for _ in 0..<600 { ref.update(headYaw: head, deltaTime: 1.0 / 60.0, tuning: tuning) }
        #expect(abs(ref.forwardYaw - head) < 0.05 && !ref.isRecentering)
    }

    @Test func missingHeadYawLeavesReferenceAlone() {
        var ref = ChaseCameraReference(forwardYaw: 1.1)
        for _ in 0..<300 { ref.update(headYaw: nil, deltaTime: 1.0 / 60.0, tuning: tuning) }
        #expect(ref.forwardYaw == 1.1)
    }
}

// MARK: - 카트 리그 자세 (Issue #26, 결정 51): 핸들 82°·앞바퀴 30° 핀치 연동, 차체 roll/pitch, 바퀴 굴림

struct KartRigPoseTests {
    private let tuning = KartRigTuning()

    @Test func steeringFollowsPinchAndSettlesWithinTenthOfASecond() {
        var pose = KartRigPose()
        for _ in 0..<9 { pose.update(drive: .turnLeft, speed: 0, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning) }
        // lerp(dt×14)를 0.1초: 1 − (1 − 14/90)^9 ≈ 0.78 이상
        #expect(pose.steer > 0.75)
        #expect(pose.steeringWheelAngle(tuning: tuning) > 0.75 * 82 && pose.frontWheelAngle(tuning: tuning) > 0.75 * 30)
        for _ in 0..<90 { pose.update(drive: .turnRight, speed: 0, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning) }
        #expect(pose.steer < -0.99)
        for _ in 0..<90 { pose.update(drive: .stopped, speed: 0, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning) }
        #expect(abs(pose.steer) < 0.01, "손을 떼면 핸들이 돌아온다")
    }

    @Test func bodyRollsOutwardProportionalToSpeed() {
        var slow = KartRigPose(), fast = KartRigPose()
        for _ in 0..<180 {
            slow.update(drive: .turnLeft, speed: 1, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning)
            fast.update(drive: .turnLeft, speed: 4, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning)
        }
        // 왼쪽으로 돌면 roll은 음수(바깥=오른쪽), 최고 속도에서 약 −4°
        #expect(fast.roll < slow.roll && slow.roll < 0)
        #expect(abs(fast.roll + tuning.bodyRollDegrees) < 0.1)
    }

    @Test func pitchFollowsAccelerationSign() {
        var pose = KartRigPose()
        for _ in 0..<90 { pose.update(drive: .pedal(1), speed: 2, maxSpeed: 4, acceleration: 4, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning) }
        #expect(pose.pitch > 0.9 * tuning.bodyPitchDegrees, "가속하면 뒤로")
        for _ in 0..<90 { pose.update(drive: .stopped, speed: 2, maxSpeed: 4, acceleration: -4, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning) }
        #expect(pose.pitch < -0.9 * tuning.bodyPitchDegrees, "감속하면 앞으로")
    }

    @Test func wheelSpinMatchesTravelDistance() {
        var pose = KartRigPose()
        // 반지름 0.1 m, 2 m/s로 0.1초 → 0.2 m 이동 = 2 rad ≈ 114.6°
        for _ in 0..<9 { pose.update(drive: .pedal(1), speed: 2, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1.0 / 90.0, tuning: tuning) }
        #expect(abs(pose.wheelSpin - 114.59) < 0.5)
        var still = KartRigPose()
        still.update(drive: .stopped, speed: 0, maxSpeed: 4, acceleration: 0, wheelRadius: 0.1, deltaTime: 1, tuning: tuning)
        #expect(still.wheelSpin == 0, "정지하면 바퀴가 멈춘다")
    }
}

// MARK: - 레이스 흐름 (M5, 결정 56): 카운트다운 → GO → 랩 기록 → 완주

@MainActor
struct RaceModelTests {
    @Test func pauseFreezesTimerAndResumeKeepsRecords() {
        let model = RaceModel()
        model.start(totalLaps: 3)
        model.pause()
        #expect(model.hud.phase == .countdown(3), "카운트다운 중에는 일시정지가 없다")
        model.go()
        model.updateMotion(speedMetersPerSecond: 2, deltaTime: 1.0)
        model.pause()
        #expect(model.isPaused)
        model.updateMotion(speedMetersPerSecond: 0, deltaTime: 5.0)
        #expect(abs(model.hud.totalTime - 1.0) < 1e-9, "일시정지 중에는 시간이 흐르지 않는다")
        model.countdown(3); model.countdown(1)
        model.updateMotion(speedMetersPerSecond: 0, deltaTime: 1.0)
        #expect(abs(model.hud.totalTime - 1.0) < 1e-9, "재개 카운트다운 중에도 멈춰 있다")
        model.go()
        model.updateMotion(speedMetersPerSecond: 2, deltaTime: 0.5)
        #expect(abs(model.hud.totalTime - 1.5) < 1e-9 && abs(model.hud.lapTime - 1.5) < 1e-9, "재개 뒤 이어서 흐른다(기록 초기화 없음)")
    }

    @Test func startsInCountdownAndTimerWaitsForGo() {
        let model = RaceModel()
        model.start(totalLaps: 3)
        #expect(model.hud.phase == .countdown(3))
        model.updateMotion(speedMetersPerSecond: 0, deltaTime: 1)
        #expect(model.hud.totalTime == 0, "카운트다운 중에는 시간이 흐르지 않는다")
        model.countdown(2); model.countdown(1)
        #expect(model.hud.phase == .countdown(1))
        model.go()
        #expect(model.isRacing)
        model.updateMotion(speedMetersPerSecond: 2, deltaTime: 0.5)
        #expect(abs(model.hud.totalTime - 0.5) < 1e-9 && abs(model.hud.lapTime - 0.5) < 1e-9)
    }

    @Test func lapTimesAccumulatePerLapAndFinishClosesLastLap() {
        let model = RaceModel()
        model.start(totalLaps: 2); model.go()
        model.updateMotion(speedMetersPerSecond: 3, deltaTime: 10)
        model.updateLap(LapProgress(currentLap: 2, checkpointsPassedThisLap: 0, isFinished: false), totalCheckpoints: 3)
        #expect(model.hud.lapTimes == [10] && model.hud.lap == 2 && model.hud.lapTime == 0)
        model.updateMotion(speedMetersPerSecond: 3, deltaTime: 8)
        model.updateLap(LapProgress(currentLap: 2, checkpointsPassedThisLap: 0, isFinished: true), totalCheckpoints: 3)
        #expect(model.hud.lapTimes == [10, 8], "완주 순간 마지막 랩이 닫힌다")
        #expect(model.hud.bestLapTime == 8 && model.hud.lap == 2 && model.isFinished)
        #expect(abs(model.hud.totalTime - 18) < 1e-9)
        // 완주 뒤에는 시간도 랩도 더 쌓이지 않는다
        model.updateMotion(speedMetersPerSecond: 1, deltaTime: 5)
        model.updateLap(LapProgress(currentLap: 2, checkpointsPassedThisLap: 0, isFinished: true), totalCheckpoints: 3)
        #expect(abs(model.hud.totalTime - 18) < 1e-9 && model.hud.lapTimes.count == 2)
    }

    @Test func restartResetsEverything() {
        let model = RaceModel()
        model.start(totalLaps: 3); model.go()
        model.updateMotion(speedMetersPerSecond: 3, deltaTime: 4)
        model.start(totalLaps: 3)
        #expect(model.hud.phase == .countdown(3) && model.hud.totalTime == 0 && model.hud.lapTimes.isEmpty && model.hud.lap == 1)
    }
}
