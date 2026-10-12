#if os(visionOS) || os(iOS)
import RealityKit
import Foundation

enum KartMaterialPainter {
    @MainActor
    static func applyColor(_ colorID: String?, kart: KartModel, to entity: Entity) async {
        guard let colorID else { return }

        async let base = loadTexture(name: "\(kart.usdzResourceName)_\(colorID)")
        async let emissive = loadTexture(name: "\(kart.usdzResourceName)_\(colorID)_emissive")
        let (baseTexture, emissiveTexture) = await (base, emissive)
        guard baseTexture != nil || emissiveTexture != nil else { return }

        for descendant in entity.allDescendantsIncludingSelf() {
            guard var model = descendant.components[ModelComponent.self] else { continue }
            model.materials = model.materials.map { material -> any Material in
                guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                if let baseTexture {
                    pbr.baseColor.texture = .init(baseTexture)
                }
                if let emissiveTexture {
                    pbr.emissiveColor.texture = .init(emissiveTexture)
                    pbr.emissiveIntensity = 1.0
                }
                return pbr
            }
            descendant.components[ModelComponent.self] = model
        }
    }

    private static func loadTexture(name: String) async -> TextureResource? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return try? await TextureResource(contentsOf: url)
    }
}

extension Entity {
    func allDescendantsIncludingSelf() -> [Entity] {
        var result = [self]
        for child in children {
            result.append(contentsOf: child.allDescendantsIncludingSelf())
        }
        return result
    }
}
#endif
