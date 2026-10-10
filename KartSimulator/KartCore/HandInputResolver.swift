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
    private var lastDriveState: DriveState = .stopped

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

    @discardableResult
    public func resolve(now: TimeInterval) -> (drive: DriveState, left: HandStatus, right: HandStatus) {
        let leftStatus = status(for: left, now: now)
        let rightStatus = status(for: right, now: now)

        var distance: Float?
        if leftStatus.tracked, rightStatus.tracked,
           let lp = left.lastPosition, let rp = right.lastPosition {
            let raw = simdDistance(lp, rp)
            if let previous = smoothedDistance {
                smoothedDistance = previous + tuning.distanceSmoothing * (raw - previous)
            } else {
                smoothedDistance = raw
            }
            distance = smoothedDistance
        } else {
            smoothedDistance = nil
        }

        let state = determineState(leftStatus: leftStatus, rightStatus: rightStatus, distance: distance)
        lastDriveState = state
        return (state, leftStatus, rightStatus)
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

    private func determineState(leftStatus: HandStatus, rightStatus: HandStatus, distance: Float?) -> DriveState {
        switch (leftStatus.pinching, rightStatus.pinching) {
        case (false, false):
            return .stopped
        case (true, false):
            return .turnLeft
        case (false, true):
            return .turnRight
        case (true, true):
            guard let distance else { return .waiting }
            return forwardState(for: distance)
        }
    }

    private func forwardState(for distance: Float) -> DriveState {
        let lowerHalf = tuning.spreadHalf - tuning.spreadHysteresis
        let lowerFull = tuning.spreadFull - tuning.spreadHysteresis

        switch lastDriveState {
        case .forwardFull:
            if distance >= lowerFull { return .forwardFull }
            return distance >= lowerHalf ? .forwardHalf : .waiting
        case .forwardHalf:
            if distance >= tuning.spreadFull { return .forwardFull }
            return distance >= lowerHalf ? .forwardHalf : .waiting
        default:
            if distance >= tuning.spreadFull { return .forwardFull }
            if distance >= tuning.spreadHalf { return .forwardHalf }
            return .waiting
        }
    }

    private func simdDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let delta = a - b
        return (delta * delta).sum().squareRoot()
    }
}
