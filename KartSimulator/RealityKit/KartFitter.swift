#if os(visionOS)
import RealityKit

enum KartFitter {
    /// 카트를 고정 크기(`maxDimension`)에 맞춰 스케일한다 — 카트만 단독 전시할 때 사용.
    @MainActor
    static func fit(_ entity: Entity, maxDimension: Float) {
        let bounds = entity.visualBounds(relativeTo: entity)
        let largest = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        guard largest > 0 else { return }
        apply(scale: maxDimension / largest, to: entity, bounds: bounds)
    }

    /// 카트를 명시적 배율로 스케일한다 — 트랙과 같은 월드→박스 배율을 써서 비례를 맞출 때 사용.
    @MainActor
    static func fit(_ entity: Entity, scale: Float) {
        let bounds = entity.visualBounds(relativeTo: entity)
        apply(scale: scale, to: entity, bounds: bounds)
    }

    @MainActor
    private static func apply(scale: Float, to entity: Entity, bounds: BoundingBox) {
        let center = bounds.center
        let minY = bounds.min.y
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position = SIMD3<Float>(-center.x * scale, -minY * scale, -center.z * scale)
    }
}
#endif
