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
    /// 레일 주행(결정 58): 진행 방향 y 성분에 곱하는 중력 가속도(m/s²). `accel`보다 커야 루프에서 스로틀을 놓으면 미끄러진다.
    public var gravity: Float
    /// 내리막 보너스 상한(최고 속도의 배수).
    public var downhillSpeedCap: Float
    /// 중심선에서 카트 원점이 갈 수 있는 최대 가로 거리(m). 벽 안쪽면 2.0 − 카트 반폭 0.4.
    public var wallHalfWidth: Float

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
        gravity: Float = 4.5,
        downhillSpeedCap: Float = 1.25,
        wallHalfWidth: Float = 1.6
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
        self.gravity = gravity
        self.downhillSpeedCap = downhillSpeedCap
        self.wallHalfWidth = wallHalfWidth
    }
}
