import SwiftUI

struct ContentView: View {
    @Environment(KartSelectionModel.self) private var selection
    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif
    @State private var isImmersiveOpen = false
    @State private var isBusy = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("핀치 카트")
                        .font(.largeTitle.bold())
                    Text("카트를 고르고 박스 안에서 확인해 보세요.")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(KartCatalog.karts) { kart in
                        KartCard(kart: kart, isSelected: kart.id == selection.selectedKartID)
                            .onTapGesture { selection.selectKart(kart) }
                    }
                }

                if selection.selectedKart.hasColorVariants {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("색상")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(selection.selectedKart.colorOptions) { color in
                                    ColorSwatch(
                                        color: color,
                                        isSelected: color.id == selection.selectedColorID
                                    )
                                    .onTapGesture { selection.selectedColorID = color.id }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                #if os(visionOS)
                Button(isImmersiveOpen ? "박스 닫기" : "박스 열기") {
                    Task { await toggleImmersiveSpace() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
                #else
                Text("박스 미리보기는 비전OS에서만 열 수 있습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }
            .padding(24)
        }
    }

    #if os(visionOS)
    private func toggleImmersiveSpace() async {
        isBusy = true
        defer { isBusy = false }
        if isImmersiveOpen {
            await dismissImmersiveSpace()
            isImmersiveOpen = false
        } else if case .opened = await openImmersiveSpace(id: AppScene.immersiveSpaceID) {
            isImmersiveOpen = true
        }
    }
    #endif
}

private struct KartCard: View {
    let kart: KartModel
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 36))
                .frame(maxWidth: .infinity, minHeight: 72)
            Text(kart.displayName)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
        )
    }
}

private struct ColorSwatch: View {
    let color: KartColorOption
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(hex: color.swatchHex))
            .frame(width: 28, height: 28)
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.white.opacity(0.4),
                    lineWidth: isSelected ? 3 : 1
                )
            )
    }
}

#Preview {
    ContentView()
        .environment(KartSelectionModel())
}
