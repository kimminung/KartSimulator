#if os(visionOS)
import Foundation
import RealityKit

/// `KartSimulator/Resources/Tiles/tile_<type>.usdz`를 타입별로 한 번만 로드해 캐시해 두고,
/// 그리드에 배치할 때마다 복제(`clone`)해서 쓴다 — 타일 4종을 수십 번 다시 읽을 필요가 없다.
@MainActor
final class TrackTileLibrary {
    private var templates: [String: Entity] = [:]

    func makeTile(type: String) async -> Entity? {
        if let template = templates[type] {
            return template.clone(recursive: true)
        }
        guard let url = Bundle.main.url(forResource: "tile_\(type)", withExtension: "usdz") else {
            print("타일 리소스를 찾을 수 없습니다: tile_\(type).usdz")
            return nil
        }
        do {
            let template = try await Entity(contentsOf: url)
            templates[type] = template
            return template.clone(recursive: true)
        } catch {
            print("타일 로드 실패(tile_\(type)): \(error)")
            return nil
        }
    }
}
#endif
