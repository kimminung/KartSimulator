import Foundation

/// 프레임 시간 표본(결정 61, Issue #45): 매 프레임 `record(deltaTime:)`를 부르면 `interval`초마다 평균·최악 프레임 시간과
/// 프레임 수를 묶어 돌려준다. Instruments 없이도 콘솔(`debugLog`)로 fps를 읽기 위한 가벼운 측정기 — 시뮬레이터·실기기 공통.
public struct FrameTimeSampler: Equatable, Sendable {
    public struct Report: Equatable, Sendable {
        public let frames: Int
        public let averageMilliseconds: Double
        public let worstMilliseconds: Double
        public let seconds: Double
        public var averageFPS: Double { seconds > 0 ? Double(frames) / seconds : 0 }
    }

    public let interval: Double
    private var elapsed: Double = 0
    private var frames = 0
    private var worst: Double = 0

    public init(interval: Double = 5) {
        self.interval = interval
    }

    /// 한 프레임 기록. 구간이 찼으면 보고서를 돌려주고 새 구간을 시작한다.
    public mutating func record(deltaTime: Double) -> Report? {
        guard deltaTime > 0 else { return nil }
        elapsed += deltaTime
        frames += 1
        worst = max(worst, deltaTime)
        guard elapsed >= interval else { return nil }
        let report = Report(
            frames: frames,
            averageMilliseconds: elapsed / Double(frames) * 1000,
            worstMilliseconds: worst * 1000,
            seconds: elapsed
        )
        elapsed = 0
        frames = 0
        worst = 0
        return report
    }
}
