#if os(visionOS)
import RealityKit

enum KartFitter {
    @MainActor
    static func fit(_ entity: Entity, maxDimension: Float) {
        let bounds = entity.visualBounds(relativeTo: entity)
        let extents = bounds.extents
        let largest = max(extents.x, max(extents.y, extents.z))
        guard largest > 0 else { return }

        let scale = maxDimension / largest
        let center = bounds.center
        let minY = bounds.min.y

        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position = SIMD3<Float>(-center.x * scale, -minY * scale, -center.z * scale)
    }
}
#endif
