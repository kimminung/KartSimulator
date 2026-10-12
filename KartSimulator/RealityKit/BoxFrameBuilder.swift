#if os(visionOS) || os(iOS)
import RealityKit
import simd

enum BoxFrameBuilder {
    @MainActor
    static func makeFrame(size: SIMD3<Float>, thickness: Float, color: SimpleMaterial.Color) -> Entity {
        let root = Entity()
        root.name = "boxFrame"

        let hx = size.x / 2
        let hy = size.y / 2
        let hz = size.z / 2

        let corners: [SIMD3<Float>] = [
            [-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz],
            [-hx, hy, -hz], [hx, hy, -hz], [hx, hy, hz], [-hx, hy, hz],
        ]
        let edges: [(Int, Int)] = [
            (0, 1), (1, 2), (2, 3), (3, 0),
            (4, 5), (5, 6), (6, 7), (7, 4),
            (0, 4), (1, 5), (2, 6), (3, 7),
        ]

        let material = UnlitMaterial(color: color)
        for (a, b) in edges {
            let start = corners[a]
            let end = corners[b]
            let length = simd_distance(start, end)
            guard length > 0 else { continue }

            let mesh = MeshResource.generateBox(size: SIMD3<Float>(thickness, thickness, length))
            let edgeEntity = ModelEntity(mesh: mesh, materials: [material])
            edgeEntity.position = (start + end) / 2
            edgeEntity.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(end - start))
            root.addChild(edgeEntity)
        }

        return root
    }
}
#endif
