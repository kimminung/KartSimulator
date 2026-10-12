import Foundation

/// 트랙 월드 좌표(XZ, 미터) → 미니맵 로컬 좌표(XZ, 미터) 변환 (테크 PRD 9·10장, 결정 48).
/// 지름 `tableDiameter`인 둥근 테이블 위에 트랙 바운딩 박스(노면 폭 포함)가 들어가도록 **등방 배율**로 축소하고
/// 트랙 중심을 테이블 중심에 놓는다. 축은 트랙 좌표계 그대로(x → x, z → z)라 heading도 그대로 쓴다.
public struct MinimapProjection: Equatable, Sendable {
    /// 트랙 바운딩 박스 중심(월드 XZ).
    public let center: SIMD2<Float>
    /// 미니맵 m / 월드 m.
    public let scale: Float
    public let tableDiameter: Float

    /// `points`: 중심선 점열, `trackWidth`: 노면 폭(바운딩 박스에 반폭씩 여유로 더한다).
    /// 원에 내접하는 정사각형(변 = 지름/√2 ≈ 0.707 지름)의 `fill` 비율만 쓴다 — 기본 0.9면 지름의 약 64 %.
    public init(points: [SIMD2<Float>], trackWidth: Float, tableDiameter: Float, fill: Float = 0.9) {
        self.tableDiameter = tableDiameter
        guard let first = points.first else {
            center = .zero
            scale = 1
            return
        }
        var minX = first.x, maxX = first.x, minZ = first.y, maxZ = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minZ = min(minZ, p.y); maxZ = max(maxZ, p.y)
        }
        let half = trackWidth / 2
        minX -= half; maxX += half; minZ -= half; maxZ += half
        center = SIMD2((minX + maxX) / 2, (minZ + maxZ) / 2)
        let span = max(maxX - minX, maxZ - minZ, 0.001)
        let usable = tableDiameter / Float(2).squareRoot() * fill
        scale = usable / span
    }

    /// 월드 XZ → 미니맵 로컬 XZ.
    public func mapPosition(_ worldXZ: SIMD2<Float>) -> SIMD2<Float> {
        (worldXZ - center) * scale
    }

    /// 월드 길이 → 미니맵 길이.
    public func mapLength(_ worldLength: Float) -> Float {
        worldLength * scale
    }

    /// 체크포인트 n개 중 이번 랩에 지난 개수가 `passed`일 때, 라벨 i(0부터)가 통과 상태인지.
    /// `LapTracker`는 순서대로만 통과시키므로 앞에서부터 `passed`개가 통과다.
    public static func isCheckpointPassed(ordinal: Int, passedCount: Int) -> Bool {
        ordinal < passedCount
    }
}
