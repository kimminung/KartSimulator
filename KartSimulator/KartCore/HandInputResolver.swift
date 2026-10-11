import Foundation

public enum HandChirality: Sendable {
    case left
    case right
}

public struct HandSample: Sendable {
    public var chirality: HandChirality
    public var isPinching: Bool
    public var position: SIMD3<Float>?
    public var timestamp: TimeInterval

    public init(chirality: HandChirality, isPinching: Bool, position: SIMD3<Float>?, timestamp: TimeInterval) {
        self.chirality = chirality
        self.isPinching = isPinching
        self.position = position
        self.timestamp = timestamp
    }
}

public struct HandStatus: Equatable, Sendable {
    public var tracked: Bool
    public var pinching: Bool
}

/// Turns raw per-hand pinch samples (from SpatialEventGesture in the app layer) into a `DriveState`,
/// applying the debounce/grace/stale timers and spread hysteresis from `InputTuning`.
public final class HandInputResolver {
    private struct HandState {
        var isPinchingRaw = false
        var pinchBeganAt: TimeInterval = -.infinity
        var pinchEndedAt: TimeInterval = -.infinity
        var lastEventTime: TimeInterval = -.infinity
        var lastPosition: SIMD3<Float>?
    }

    public var tuning: InputTuning
    private var left = HandState()
    private var right = HandState()
    private var smoothedDistance: Float?
    /// 디오라마 모드 전용: 양손이 핀치를 시작한 순간의 거리(상대 거리 기준점). 둘 중 하나라도
    /// 떼면 지운다 — 다시 양손을 모으면 그 새 순간이 새 기준점이 된다.
    private var bothPinchBaselineDistance: Float?

    public init(tuning: InputTuning = InputTuning()) {
        self.tuning = tuning
    }

    public func ingest(_ sample: HandSample) {
        var state = sample.chirality == .left ? left : right
        state.lastEventTime = sample.timestamp
        if let position = sample.position { state.lastPosition = position }

        if sample.isPinching {
            if !state.isPinchingRaw { state.pinchBeganAt = sample.timestamp }
            state.isPinchingRaw = true
        } else {
            if state.isPinchingRaw { state.pinchEndedAt = sample.timestamp }
            state.isPinchingRaw = false
        }

        if sample.chirality == .left { left = state } else { right = state }
    }

    /// `mode`에 따라 완전히 다른 의미로 손 상태를 해석한다(결정 39):
    /// - `.diorama`: 양손 핀치 = 전·후진(상대 거리 드래그), 한손만 = 회전, 아무도 안 = 정지.
    /// - `.thirdPerson`: 디오라마와 같은 손 모양이지만 후진이 없다 — 양손 핀치는 항상 전진 최대치.
    /// - `.firstPerson`: 손은 가속 여부만 맡는다(한쪽이라도 핀치하면 가속) — 조향은 머리 방향으로
    ///   따로 들어온다(`ImmersiveBoxView`가 `desiredHeading`을 계산해 `KartMotionState`에 넘김).
    @discardableResult
    public func resolve(now: TimeInterval, mode: ExperienceMode) -> (drive: DriveState, left: HandStatus, right: HandStatus) {
        let leftStatus = status(for: left, now: now)
        let rightStatus = status(for: right, now: now)

        let drive: DriveState
        switch mode {
        case .diorama:
            drive = resolveDiorama(leftStatus: leftStatus, rightStatus: rightStatus)
        case .thirdPerson:
            bothPinchBaselineDistance = nil
            drive = resolveThirdPerson(leftStatus: leftStatus, rightStatus: rightStatus)
        case .firstPerson:
            bothPinchBaselineDistance = nil
            drive = .headSteered(accelerating: leftStatus.pinching || rightStatus.pinching)
        }
        return (drive, leftStatus, rightStatus)
    }

    private func resolveThirdPerson(leftStatus: HandStatus, rightStatus: HandStatus) -> DriveState {
        switch (leftStatus.pinching, rightStatus.pinching) {
        case (false, false): return .stopped
        case (true, false): return .turnLeft
        case (false, true): return .turnRight
        case (true, true): return .pedal(1.0)
        }
    }

    private func resolveDiorama(leftStatus: HandStatus, rightStatus: HandStatus) -> DriveState {
        switch (leftStatus.pinching, rightStatus.pinching) {
        case (false, false):
            smoothedDistance = nil
            bothPinchBaselineDistance = nil
            return .stopped
        case (true, false):
            bothPinchBaselineDistance = nil
            return .turnLeft
        case (false, true):
            bothPinchBaselineDistance = nil
            return .turnRight
        case (true, true):
            guard let lp = left.lastPosition, let rp = right.lastPosition else {
                bothPinchBaselineDistance = nil
                return .waiting
            }
            let raw = simdDistance(lp, rp)
            let distance: Float
            if let previous = smoothedDistance {
                distance = previous + tuning.distanceSmoothing * (raw - previous)
            } else {
                distance = raw
            }
            smoothedDistance = distance
            let baseline = bothPinchBaselineDistance ?? distance
            bothPinchBaselineDistance = baseline
            return .pedal(dioramaPedalValue(distance: distance, baseline: baseline))
        }
    }

    /// 양손 핀치 시작 지점(`baseline`) 대비 상대 거리로 전·후진을 가른다 — "전진은 핀치 유지,
    /// 벌리면 후진"(결정 39). 기준점에 가깝거나 더 좁히면(음수 드래그) 항상 전진 최대치고,
    /// `reverseDragDeadband`보다 더 벌리면 그만큼 후진이 세진다.
    private func dioramaPedalValue(distance: Float, baseline: Float) -> Float {
        let drag = distance - baseline
        if drag <= tuning.reverseDragDeadband { return 1.0 }
        let span = max(tuning.reverseDragSpan, 0.0001)
        let fraction = min(max((drag - tuning.reverseDragDeadband) / span, 0), 1)
        return -fraction
    }

    private func status(for hand: HandState, now: TimeInterval) -> HandStatus {
        let tracked = (now - hand.lastEventTime) <= tuning.staleTimeout
        guard tracked else { return HandStatus(tracked: false, pinching: false) }

        if hand.isPinchingRaw {
            let heldFor = now - hand.pinchBeganAt
            return HandStatus(tracked: true, pinching: heldFor >= tuning.pinchDebounce)
        }

        let sinceRelease = now - hand.pinchEndedAt
        if sinceRelease <= tuning.releaseGrace {
            return HandStatus(tracked: true, pinching: true)
        }
        return HandStatus(tracked: true, pinching: false)
    }

    private func simdDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let delta = a - b
        return (delta * delta).sum().squareRoot()
    }
}
