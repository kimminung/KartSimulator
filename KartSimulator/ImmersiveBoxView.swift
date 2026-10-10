#if os(visionOS)
import SwiftUI
import RealityKit

struct ImmersiveBoxView: View {
    @Environment(KartSelectionModel.self) private var selection

    @State private var rootEntity = Entity()
    @State private var kartSlot = Entity()
    @State private var loadedKartID: String?
    @State private var loadedColorID: String?
    @State private var isLoading = false

    private let boxSize: SIMD3<Float> = [0.7, 0.4, 0.7]
    private let boxPosition: SIMD3<Float> = [0, 1.05, -1.1]

    var body: some View {
        RealityView { content in
            rootEntity.position = boxPosition

            let frame = BoxFrameBuilder.makeFrame(size: boxSize, thickness: 0.006, color: .white)
            rootEntity.addChild(frame)

            let floor = ModelEntity(
                mesh: .generateBox(width: boxSize.x * 0.96, height: 0.01, depth: boxSize.z * 0.96),
                materials: [SimpleMaterial(color: .init(white: 0.22, alpha: 1), roughness: 0.6, isMetallic: false)]
            )
            floor.position.y = -boxSize.y / 2 + 0.005
            rootEntity.addChild(floor)

            kartSlot.name = "kartSlot"
            kartSlot.position.y = -boxSize.y / 2 + 0.01
            rootEntity.addChild(kartSlot)

            content.add(rootEntity)
        } update: { _ in
            guard !isLoading,
                  loadedKartID != selection.selectedKartID || loadedColorID != selection.selectedColorID
            else { return }

            isLoading = true
            Task {
                await loadKart()
                isLoading = false
            }
        }
    }

    @MainActor
    private func loadKart() async {
        let kart = selection.selectedKart
        let colorID = selection.selectedColorID

        guard let url = Bundle.main.url(forResource: kart.usdzResourceName, withExtension: "usdz") else {
            print("카트 리소스를 찾을 수 없습니다: \(kart.usdzResourceName).usdz")
            return
        }

        do {
            let entity = try await Entity(contentsOf: url)
            await KartMaterialPainter.applyColor(colorID, kart: kart, to: entity)
            KartFitter.fit(entity, maxDimension: 0.22)

            kartSlot.children.removeAll()
            kartSlot.addChild(entity)

            loadedKartID = kart.id
            loadedColorID = colorID
        } catch {
            print("카트 로드 실패(\(kart.usdzResourceName)): \(error)")
        }
    }
}
#endif
