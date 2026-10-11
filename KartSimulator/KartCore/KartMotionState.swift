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

    /// `desiredHeading`은 `drive == .headSteered`일 때만 쓰인다(1인칭의 머리 방향 조향).
    /// 다른 모드는 손 입력(`turnLeft`/`turnRight`)만으로 회전한다 — 둘을 같은 파라미터로 억지로
    /// 합치지 않고 나란히 둔 이유는 1인칭에서 조향(머리)과 가속(손)이 서로 독립된 입력이기
    /// 때문이다(결정 39).
    public func advancing(drive: DriveState, desiredHeading: Float? = nil, tuning: MotionTuning, deltaTime: Float) -> KartMotionState {
        var next = self

        let target = Self.target(for: drive, current: speed, tuning: tuning)
        let rate = target > speed ? tuning.accel : Self.decelRate(for: drive, tuning: tuning)
        next.speed = Self.approach(speed, toward: target, by: rate * deltaTime)

        // 전진/후진 어느 쪽으로 움직이고 있어도 회전은 가능해야 한다 — 속도의 "크기"만 본다.
        if (drive == .turnLeft || drive == .turnRight), abs(next.speed) >= tuning.minTurnSpeed || next.speed == 0 {
            let t = min(max(next.speed / tuning.maxSpeed, 0), 1)
            let turnRateDegrees = tuning.turnRateLow + (tuning.turnRateHigh - tuning.turnRateLow) * t
            let sign: Float = drive == .turnLeft ? 1 : -1
            next.heading += sign * turnRateDegrees * (.pi / 180) * deltaTime
        } else if case .headSteered = drive, let desiredHeading {
            next.heading = Self.steer(from: next.heading, toward: desiredHeading, maxDegreesPerSecond: tuning.steerRateDegrees, deltaTime: deltaTime)
        }

        let forward = SIMD3<Float>(-sin(next.heading), 0, -cos(next.heading))
        next.position += forward * next.speed * deltaTime
        return next
    }

    /// `heading`을 `desiredHeading` 쪽으로 최단 방향(±π 경계를 넘나들어도 더 짧은 쪽)으로,
    /// 이번 프레임에 허용된 최대 각도(`maxDegreesPerSecond * deltaTime`)만큼만 돌린다.
    private static func steer(from heading: Float, toward desiredHeading: Float, maxDegreesPerSecond: Float, deltaTime: Float) -> Float {
        let rawDelta = desiredHeading - heading
        let shortestDelta = atan2(sin(rawDelta), cos(rawDelta))
        let maxStep = maxDegreesPerSecond * (.pi / 180) * deltaTime
        let clampedDelta = min(max(shortestDelta, -maxStep), maxStep)
        return heading + clampedDelta
    }

    private static func target(for drive: DriveState, current: Float, tuning: MotionTuning) -> Float {
        switch drive {
        case .stopped, .waiting: return 0
        case .turnLeft, .turnRight: return current
        case .pedal(let value):
            let clamped = min(max(value, -1), 1)
            return clamped >= 0 ? clamped * tuning.maxSpeed : clamped * tuning.maxSpeed * tuning.reverseSpeedFactor
        case .headSteered(let accelerating):
            return accelerating ? tuning.maxSpeed : 0
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
