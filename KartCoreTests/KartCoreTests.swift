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

    @Test func bothHandsCloseIsWaiting() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.10)
        let result = resolver.resolve(now: 0.1)
        #expect(result.drive == .waiting)
    }

    @Test func bothHandsHalfSpreadIsForwardHalf() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.30)
        let result = resolver.resolve(now: 0.1)
        #expect(result.drive == .forwardHalf)
    }

    @Test func bothHandsFullSpreadIsForwardFull() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.50)
        let result = resolver.resolve(now: 0.1)
        #expect(result.drive == .forwardFull)
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

    @Test func hysteresisKeepsForwardFullUntilDroppingBelowMargin() {
        let resolver = HandInputResolver()
        feedBothHands(resolver, distance: 0.50, timestamp: 0)
        #expect(resolver.resolve(now: 0.05).drive == .forwardFull)

        // Distance dips just under spreadFull but still above the hysteresis margin (0.40 - 0.03).
        feedBothHands(resolver, distance: 0.38, timestamp: 0.1)
        #expect(resolver.resolve(now: 0.15).drive == .forwardFull)

        // Distance drops below the hysteresis margin. The smoothed distance (EMA, alpha 0.25)
        // takes a few frames to catch up to the new raw reading, so feed several frames before asserting.
        var lastState = DriveState.forwardFull
        for frame in 1...10 {
            let t = 0.1 + Double(frame) * (1.0 / 60.0)
            feedBothHands(resolver, distance: 0.30, timestamp: t)
            lastState = resolver.resolve(now: t + 0.001).drive
        }
        #expect(lastState == .forwardHalf)
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
            state = state.advancing(drive: .forwardFull, tuning: tuning, deltaTime: 1.0 / 60.0)
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
