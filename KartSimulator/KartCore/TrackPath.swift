import Foundation

/// 트랙 중심선(`path`)에 대한 투영·거리 계산. 닫힌 폴리라인으로 다룬다.
public struct TrackPath: Sendable {
    public let points: [SIMD2<Float>]

    public init(points: [SIMD2<Float>]) {
        self.points = points
    }

    public init(_ track: TrackDefinition) {
        self.points = track.path.map(\.vector)
    }

    /// 주어진 위치에서 가장 가까운 구간의 시작 인덱스, 중심선까지의 수직 거리, 중심선 위 투영점.
    /// 투영점은 벽 충돌 시 카트를 중심선 쪽으로 밀어내는 기준점으로 쓴다(`ImmersiveBoxView.tickMotion`).
    public func closestSegment(to position: SIMD2<Float>) -> (index: Int, distance: Float, projected: SIMD2<Float>) {
        guard !points.isEmpty else { return (0, 0, position) }
        let n = points.count
        var bestIndex = 0
        var bestDistanceSquared = Float.greatestFiniteMagnitude
        var bestProjected = points[0]

        for i in 0..<n {
            let a = points[i]
            let b = points[(i + 1) % n]
            let ab = b - a
            let lengthSquared = (ab * ab).sum()
            let t: Float
            if lengthSquared > 0 {
                t = min(max(((position - a) * ab).sum() / lengthSquared, 0), 1)
            } else {
                t = 0
            }
            let projected = a + ab * t
            let diff = position - projected
            let distanceSquared = (diff * diff).sum()
            if distanceSquared < bestDistanceSquared {
                bestDistanceSquared = distanceSquared
                bestIndex = i
                bestProjected = projected
            }
        }

        return (bestIndex, bestDistanceSquared.squareRoot(), bestProjected)
    }
}
