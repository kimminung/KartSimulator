import Foundation

public struct InputTuning: Sendable {
    /// 디오라마 모드 전용(결정 39) — 양손이 핀치를 "시작한 순간"의 손 사이 거리를 기준점(baseline)으로
    /// 잡는다. 그 기준점 근처(±이 거리)를 유지하거나 더 좁히면 전진, 기준점보다 이 거리를 넘겨서
    /// 벌리면 후진으로 바뀐다. 절대 거리(예: "40cm")가 아니라 "핀치 시작 시점 대비 상대 거리"라서,
    /// 손을 어디서 모으든(가까이든 멀리든) 그 자리를 기준으로 전진/후진이 갈린다.
    public var reverseDragDeadband: Float
    /// 기준점보다 이 거리만큼 더 벌어지면 후진 페달이 최대치(-1)가 된다.
    public var reverseDragSpan: Float
    public var releaseGrace: TimeInterval
    public var pinchDebounce: TimeInterval
    public var staleTimeout: TimeInterval
    public var distanceSmoothing: Float

    public init(
        reverseDragDeadband: Float = 0.04,
        reverseDragSpan: Float = 0.25,
        releaseGrace: TimeInterval = 0.120,
        pinchDebounce: TimeInterval = 0.040,
        staleTimeout: TimeInterval = 0.300,
        distanceSmoothing: Float = 0.25
    ) {
        self.reverseDragDeadband = reverseDragDeadband
        self.reverseDragSpan = reverseDragSpan
        self.releaseGrace = releaseGrace
        self.pinchDebounce = pinchDebounce
        self.staleTimeout = staleTimeout
        self.distanceSmoothing = distanceSmoothing
    }
}
