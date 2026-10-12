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

    /// 손 입력(`DriveState`)만으로 가감속·회전한다. 1인칭의 머리 방향 조향(`desiredHeading`)은 결정 47·49로 폐기됐다.
    public func advancing(drive: DriveState, tuning: MotionTuning, deltaTime: Float) -> KartMotionState {
        var next = self

        let target = Self.targetSpeed(for: drive, current: speed, tuning: tuning)
        let rate = target > speed ? tuning.accel : Self.decelRate(for: drive, tuning: tuning)
        next.speed = Self.approach(speed, toward: target, by: rate * deltaTime)

        // 전진/후진 어느 쪽으로 움직이고 있어도 회전은 가능해야 한다 — 속도의 "크기"만 본다.
        if (drive == .turnLeft || drive == .turnRight), abs(next.speed) >= tuning.minTurnSpeed || next.speed == 0 {
            let t = min(max(next.speed / tuning.maxSpeed, 0), 1)
            let turnRateDegrees = tuning.turnRateLow + (tuning.turnRateHigh - tuning.turnRateLow) * t
            let sign: Float = drive == .turnLeft ? 1 : -1
            next.heading += sign * turnRateDegrees * (.pi / 180) * deltaTime
        }

        let forward = SIMD3<Float>(-sin(next.heading), 0, -cos(next.heading))
        next.position += forward * next.speed * deltaTime
        return next
    }

    /// 목표 속도(`RailMotionState`도 같은 규칙을 쓴다).
    static func targetSpeed(for drive: DriveState, current: Float, tuning: MotionTuning) -> Float {
        switch drive {
        case .stopped, .waiting: return 0
        case .turnLeft, .turnRight: return current
        case .pedal(let value):
            let clamped = min(max(value, -1), 1)
            return clamped >= 0 ? clamped * tuning.maxSpeed : clamped * tuning.maxSpeed * tuning.reverseSpeedFactor
        }
    }

    static func decelRate(for drive: DriveState, tuning: MotionTuning) -> Float {
        drive == .waiting ? tuning.brakeDecel : tuning.coastDecel
    }

    static func approach(_ value: Float, toward target: Float, by maxDelta: Float) -> Float {
        guard maxDelta > 0 else { return value }
        if value < target { return min(value + maxDelta, target) }
        if value > target { return max(value - maxDelta, target) }
        return value
    }
}
