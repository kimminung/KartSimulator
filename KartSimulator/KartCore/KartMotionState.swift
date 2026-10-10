import Foundation

public struct KartMotionState: Equatable, Sendable {
    public var speed: Float
    public var heading: Float
    public var position: SIMD3<Float>

    public init(speed: Float = 0, heading: Float = 0, position: SIMD3<Float> = .zero) {
        self.speed = speed
        self.heading = heading
        self.position = position
    }

    public func advancing(drive: DriveState, tuning: MotionTuning, deltaTime: Float) -> KartMotionState {
        var next = self

        let target = Self.target(for: drive, current: speed, tuning: tuning)
        let rate = target > speed ? tuning.accel : Self.decelRate(for: drive, tuning: tuning)
        next.speed = Self.approach(speed, toward: target, by: rate * deltaTime)

        if (drive == .turnLeft || drive == .turnRight), next.speed >= tuning.minTurnSpeed || next.speed == 0 {
            let t = min(max(next.speed / tuning.maxSpeed, 0), 1)
            let turnRateDegrees = tuning.turnRateLow + (tuning.turnRateHigh - tuning.turnRateLow) * t
            let sign: Float = drive == .turnLeft ? 1 : -1
            next.heading += sign * turnRateDegrees * (.pi / 180) * deltaTime
        }

        let forward = SIMD3<Float>(-sin(next.heading), 0, -cos(next.heading))
        next.position += forward * next.speed * deltaTime
        return next
    }

    private static func target(for drive: DriveState, current: Float, tuning: MotionTuning) -> Float {
        switch drive {
        case .stopped, .waiting: return 0
        case .turnLeft, .turnRight: return current
        case .forwardHalf: return tuning.maxSpeed * 0.5
        case .forwardFull: return tuning.maxSpeed
        }
    }

    private static func decelRate(for drive: DriveState, tuning: MotionTuning) -> Float {
        drive == .waiting ? tuning.brakeDecel : tuning.coastDecel
    }

    private static func approach(_ value: Float, toward target: Float, by maxDelta: Float) -> Float {
        guard maxDelta > 0 else { return value }
        if value < target { return min(value + maxDelta, target) }
        if value > target { return max(value - maxDelta, target) }
        return value
    }
}
