import Testing
import Foundation
@testable import KartSimulator

struct HandInputResolverTests {
    @Test func bothHandsReleasedIsStopped() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0))
        let result = resolver.resolve(now: 0)
        #expect(result.drive == .stopped)
    }

    @Test func leftOnlyPinchIsTurnLeft() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .left, at: 0, debounced: true)
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.1)
        #expect(result.drive == .turnLeft)
    }

    @Test func rightOnlyPinchIsTurnRight() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .right, at: 0, debounced: true)
        resolver.ingest(HandSample(chirality: .left, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.1)
        #expect(result.drive == .turnRight)
    }

    // 핀치인(좁힐수록)하면 전진, 핀치아웃(벌릴수록)하면 후진. 기준점(40cm, `pivotDistance`)이 중립이고,
    // 손을 완전히 모으면(거리 0) 최대 전진, `pivotDistance + reverseSpan`만큼 벌리면 최대 후진이다.

    @Test func handsFullyTogetherIsFullForward() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.0)
        let result = resolver.resolve(now: 0.1)
        #expect(abs((pedalValue(result.drive) ?? 0) - 1.0) < 0.001)
    }

    @Test func narrowerThanPivotIsForward() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.19) // pivotDistance(0.40)의 절반 근처
        let result = resolver.resolve(now: 0.1)
        #expect((pedalValue(result.drive) ?? 0) > 0, "40cm보다 좁히면(핀치인) 전진(양수)이어야 한다")
    }

    @Test func pinchingInFurtherAcceleratesForwardMore() {
        let narrower = resolverPedal(distance: 0.10)
        let wider = resolverPedal(distance: 0.30)
        #expect(narrower > 0 && wider > 0)
        #expect(narrower > wider, "더 좁힐수록(핀치인) 전진이 더 강해져야 한다")
    }

    @Test func atPivotLowerEdgeIsNeutral() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.38) // pivotDistance - pivotDeadband
        let result = resolver.resolve(now: 0.1)
        #expect(pedalValue(result.drive) == 0)
    }

    @Test func widerThanPivotIsReverse() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.60)
        let result = resolver.resolve(now: 0.1)
        #expect((pedalValue(result.drive) ?? 0) < 0, "40cm보다 벌리면(핀치아웃) 후진(음수)이어야 한다")
    }

    @Test func pinchingOutFurtherAcceleratesReverseMore() {
        let narrower = resolverPedal(distance: 0.50)
        let wider = resolverPedal(distance: 0.70)
        #expect(narrower < 0 && wider < 0)
        #expect(wider < narrower, "더 벌릴수록(핀치아웃) 후진이 더 강해져야 한다")
    }

    @Test func atPivotUpperEdgeIsNeutral() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.42) // pivotDistance + pivotDeadband
        let result = resolver.resolve(now: 0.1)
        #expect(pedalValue(result.drive) == 0)
    }

    @Test func exactlyAtPivotIsNeutral() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.40)
        let result = resolver.resolve(now: 0.1)
        #expect(pedalValue(result.drive) == 0, "기준점 바로 근처는 데드밴드라 중립이어야 한다")
    }

    @Test func atMaxReverseSpanIsFullReverse() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.82) // pivotDistance + pivotDeadband + reverseSpan
        let result = resolver.resolve(now: 0.1)
        #expect(abs((pedalValue(result.drive) ?? 0) - (-1.0)) < 0.001)
    }

    @Test func beyondMaxReverseSpanClampsInsteadOfOvershooting() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 1.20) // reverseSpan 범위를 한참 넘김
        let result = resolver.resolve(now: 0.1)
        #expect(abs((pedalValue(result.drive) ?? 0) - (-1.0)) < 0.001, "-1보다 더 내려가지(overshoot) 않아야 한다")
    }

    private func resolverPedal(distance: Float) -> Float {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: distance)
        return pedalValue(resolver.resolve(now: 0.1).drive) ?? 0
    }

    private func pedalValue(_ drive: DriveState) -> Float? {
        if case .pedal(let value) = drive { return value }
        return nil
    }

    @Test func pinchBelowDebounceDoesNotCountYet() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0))
        // Only 10ms held, debounce requires 40ms by default.
        let result = resolver.resolve(now: 0.010)
        #expect(result.drive == .stopped)
    }

    @Test func releaseWithinGraceStillCountsAsPinching() {
        let resolver = HandInputResolver()
        feedPinch(resolver, .left, at: 0, debounced: true)
        feedPinch(resolver, .right, at: 0, debounced: true)
        // Right hand releases, but within the 120ms grace window.
        resolver.ingest(HandSample(chirality: .right, isPinching: false, position: nil, timestamp: 0.1))
        let result = resolver.resolve(now: 0.15)
        #expect(result.drive != .turnLeft, "release grace should still count the right hand as pinching")
    }

    @Test func staleHandIsReportedUntracked() {
        let resolver = HandInputResolver()
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: nil, timestamp: 0))
        resolver.ingest(HandSample(chirality: .right, isPinching: true, position: nil, timestamp: 0))
        // No further events for the right hand past staleTimeout (300ms default).
        resolver.ingest(HandSample(chirality: .left, isPinching: true, position: nil, timestamp: 0.5))
        let result = resolver.resolve(now: 0.5)
        #expect(result.right.tracked == false)
    }

    @Test func distanceSmoothingEasesSuddenJumps() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.0, timestamp: 0) // 최대 전진 지점(손을 완전히 모음)
        #expect(abs((pedalValue(resolver.resolve(now: 0.05).drive) ?? 0) - 1.0) < 0.001)

        // 거리가 순간적으로 0.82(최대 후진 지점)로 뛰어도, EMA(alpha 0.25)가 바로 따라가지 않고 서서히 수렴한다.
        feedBothHands(resolver, distance: 0.82, timestamp: 0.1)
        let justAfterJump = pedalValue(resolver.resolve(now: 0.15).drive) ?? 0
        #expect(justAfterJump > -1.0, "EMA 스무딩 때문에 한 프레임만에 최대 후진까지 가지는 않아야 한다")

        var lastValue = justAfterJump
        for frame in 1...20 {
            let t = 0.1 + Double(frame) * (1.0 / 60.0)
            feedBothHands(resolver, distance: 0.82, timestamp: t)
            lastValue = pedalValue(resolver.resolve(now: t + 0.001).drive) ?? 0
        }
        #expect(lastValue < -0.9, "충분히 시간이 지나면 거리(0.82)에 맞는 값으로 수렴해야 한다")
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
