import Foundation
import simd

/// 트랙 중심선의 3D 프레임 열(결정 58). 스키마 2 서킷은 `gen_circuit.py`가 낸 `frames`를 그대로 쓰고,
/// 스키마 1 격자 트랙은 평면 `path`에서 만든다(y = 노면 높이, 법선 +Y). 호 길이 `s`로 보간해 위치·진행 방향·
/// 노면 법선·평면 yaw 곡률을 돌려준다. `RailMotionState`가 이 위를 달린다.
///
/// 관례: 진행 방향 `tangent`, 노면 법선 `up`(카트 쪽), 오른쪽 `right = tangent × up`. 평면 yaw 곡률 `yawCurvature`는
/// 좌회전이 양수(1/m) — 트랙이 왼쪽으로 Δ만큼 돌면 방향을 유지한 카트는 상대적으로 오른쪽을 보게 된다.
public struct TrackSpline: Sendable {
    public struct Frame: Equatable, Sendable {
        public var position: SIMD3<Float>
        public var tangent: SIMD3<Float>
        public var up: SIMD3<Float>
        public var yawCurvature: Float
        public var right: SIMD3<Float> { simd_normalize(simd_cross(tangent, up)) }

        public init(position: SIMD3<Float>, tangent: SIMD3<Float>, up: SIMD3<Float>, yawCurvature: Float) {
            self.position = position
            self.tangent = tangent
            self.up = up
            self.yawCurvature = yawCurvature
        }
    }

    public let frames: [Frame]
    /// 각 프레임의 누적 호 길이(m). `arcLengths[i]` = 프레임 0에서 i까지.
    public let arcLengths: [Float]
    /// 닫힌 한 바퀴 길이(마지막 프레임 → 첫 프레임 포함).
    public let totalLength: Float
    public let maxHeight: Float

    public init(frames: [Frame]) {
        precondition(frames.count >= 2, "프레임이 2개 이상이어야 한다")
        self.frames = frames
        var lengths: [Float] = [0]
        lengths.reserveCapacity(frames.count)
        for i in 1..<frames.count {
            lengths.append(lengths[i - 1] + simd_distance(frames[i].position, frames[i - 1].position))
        }
        self.arcLengths = lengths
        self.totalLength = lengths[frames.count - 1] + simd_distance(frames[frames.count - 1].position, frames[0].position)
        self.maxHeight = frames.map(\.position.y).max() ?? 0
    }

    /// 트랙 정의에서 만든다. 스키마 2는 `frames`, 스키마 1은 평면 `path`(노면 높이 `surfaceHeight`, 곡률은 꺾인 각/구간 길이).
    public init?(track: TrackDefinition) {
        if let packed = track.frames, packed.count >= 2 {
            self.init(frames: packed.compactMap { f -> Frame? in
                guard f.count >= 10 else { return nil }
                return Frame(
                    position: SIMD3(f[0], f[1], f[2]),
                    tangent: simd_normalize(SIMD3(f[3], f[4], f[5])),
                    up: simd_normalize(SIMD3(f[6], f[7], f[8])),
                    yawCurvature: f[9]
                )
            })
            return
        }
        let points = track.path.map(\.vector)
        guard points.count >= 2 else { return nil }
        let n = points.count
        let y = track.surfaceHeight
        var frames: [Frame] = []
        frames.reserveCapacity(n)
        for i in 0..<n {
            let prev = points[(i - 1 + n) % n], cur = points[i], next = points[(i + 1) % n]
            let dOut = next - cur, dIn = cur - prev
            let lenOut = max(simd_length(dOut), 1e-4), lenIn = max(simd_length(dIn), 1e-4)
            let tangent2 = simd_normalize(dOut / lenOut + dIn / lenIn)
            // 꺾인 각(좌회전 +): heading h = atan2(−x, −z)
            let hIn = atan2(-dIn.x, -dIn.y), hOut = atan2(-dOut.x, -dOut.y)
            let turn = atan2(sin(hOut - hIn), cos(hOut - hIn))
            let curvature = turn / ((lenIn + lenOut) / 2)
            frames.append(Frame(
                position: SIMD3(cur.x, y, cur.y),
                tangent: SIMD3(tangent2.x, 0, tangent2.y),
                up: SIMD3(0, 1, 0),
                yawCurvature: curvature
            ))
        }
        self.init(frames: frames)
    }

    /// `s`를 [0, totalLength)로 감는다.
    public func wrapped(_ s: Float) -> Float {
        guard totalLength > 0 else { return 0 }
        var v = s.truncatingRemainder(dividingBy: totalLength)
        if v < 0 { v += totalLength }
        return v
    }

    /// `s`가 속한 프레임 구간의 시작 인덱스(= `path` 인덱스, 랩 판정용).
    public func frameIndex(at s: Float) -> Int {
        let v = wrapped(s)
        var lo = 0, hi = frames.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if arcLengths[mid] <= v { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// 호 길이 `s`의 보간 프레임. 위치는 선형, 방향·법선은 정규화 보간(인접 프레임 간 각도가 작아 충분하다).
    public func frame(at s: Float) -> Frame {
        let v = wrapped(s)
        let i = frameIndex(at: v)
        let j = (i + 1) % frames.count
        let segmentLength = j == 0 ? (totalLength - arcLengths[i]) : (arcLengths[j] - arcLengths[i])
        let t = segmentLength > 1e-6 ? min(max((v - arcLengths[i]) / segmentLength, 0), 1) : 0
        let a = frames[i], b = frames[j]
        return Frame(
            position: simd_mix(a.position, b.position, SIMD3(repeating: t)),
            tangent: simd_normalize(simd_mix(a.tangent, b.tangent, SIMD3(repeating: t))),
            up: simd_normalize(simd_mix(a.up, b.up, SIMD3(repeating: t))),
            yawCurvature: a.yawCurvature + (b.yawCurvature - a.yawCurvature) * t
        )
    }

    /// 프레임 인덱스의 호 길이(출발선 등 `path` 인덱스를 `s`로 바꿀 때).
    public func arcLength(ofFrame index: Int) -> Float {
        arcLengths[min(max(index, 0), arcLengths.count - 1)]
    }
}
