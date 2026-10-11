import Foundation

public struct MotionTuning: Sendable {
    public var maxSpeed: Float
    public var accel: Float
    public var coastDecel: Float
    public var brakeDecel: Float
    public var turnRateLow: Float
    public var turnRateHigh: Float
    public var minTurnSpeed: Float
    public var wallSpeedKeep: Float
    public var offTrackRespawn: TimeInterval
    public var respawnSpeed: Float
    /// 후진 최고 속도 = `maxSpeed * reverseSpeedFactor`.
    public var reverseSpeedFactor: Float
    /// 1인칭 전용: 머리 방향(`desiredHeading`)을 따라갈 때 초당 최대 회전각(도). 디오라마·3인칭의
    /// `turnRateLow`/`turnRateHigh`(손 회전)와는 별개 값이다(결정 39).
    public var steerRateDegrees: Float

    public init(
        maxSpeed: Float = 4.0,
        accel: Float = 3.0,
        coastDecel: Float = 2.0,
        brakeDecel: Float = 5.0,
        turnRateLow: Float = 100,
        turnRateHigh: Float = 70,
        minTurnSpeed: Float = 0.3,
        wallSpeedKeep: Float = 0.5,
        offTrackRespawn: TimeInterval = 2.0,
        respawnSpeed: Float = 0,
        reverseSpeedFactor: Float = 0.5,
        steerRateDegrees: Float = 120
    ) {
        self.maxSpeed = maxSpeed
        self.accel = accel
        self.coastDecel = coastDecel
        self.brakeDecel = brakeDecel
        self.turnRateLow = turnRateLow
        self.turnRateHigh = turnRateHigh
        self.minTurnSpeed = minTurnSpeed
        self.wallSpeedKeep = wallSpeedKeep
        self.offTrackRespawn = offTrackRespawn
        self.respawnSpeed = respawnSpeed
        self.reverseSpeedFactor = reverseSpeedFactor
        self.steerRateDegrees = steerRateDegrees
    }
}
