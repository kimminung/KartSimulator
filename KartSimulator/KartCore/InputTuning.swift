import Foundation

public struct InputTuning: Sendable {
    /// 양손 핀치 거리의 기준점(40cm, 중립). 핀치인(좁힐수록)하면 전진이 세지고, 핀치아웃(벌릴수록)하면
    /// 후진이 세진다. 전진 쪽은 손을 완전히 모은 거리 0에서 최대(+1)가 된다(자연스러운 하한).
    public var pivotDistance: Float
    /// `pivotDistance`보다 이 거리만큼 더 벌어지면(핀치아웃) 후진 페달이 최대치(-1)가 된다.
    public var reverseSpan: Float
    /// 기준점 바로 근처(±이 거리)는 중립으로 둔다 — 안 그러면 40cm를 넘나들 때마다 전진/후진이 순간적으로 뒤집힌다.
    public var pivotDeadband: Float
    public var releaseGrace: TimeInterval
    public var pinchDebounce: TimeInterval
    public var staleTimeout: TimeInterval
    public var distanceSmoothing: Float

    public init(
        pivotDistance: Float = 0.40,
        reverseSpan: Float = 0.40,
        pivotDeadband: Float = 0.02,
        releaseGrace: TimeInterval = 0.120,
        pinchDebounce: TimeInterval = 0.040,
        staleTimeout: TimeInterval = 0.300,
        distanceSmoothing: Float = 0.25
    ) {
        self.pivotDistance = pivotDistance
        self.reverseSpan = reverseSpan
        self.pivotDeadband = pivotDeadband
        self.releaseGrace = releaseGrace
        self.pinchDebounce = pinchDebounce
        self.staleTimeout = staleTimeout
        self.distanceSmoothing = distanceSmoothing
    }
}
