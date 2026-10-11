import SwiftUI
import RealityKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    @Environment(KartSelectionModel.self) private var selection
    @Environment(ImmersiveSessionModel.self) private var immersiveSession
    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif
    @State private var isBusy = false
    @State private var showOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("핀치 카트")
                        // 제목에만 픽셀 폰트(Galmuri) 적용 — 본문/숫자/라벨은 시스템 폰트 유지 (디자인 결정 20-3·20-5).
                        .font(.custom("Galmuri11-Bold", size: 40, relativeTo: .largeTitle))
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
                            HStack(spacing: 14) {
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

                HStack(spacing: 12) {
                    #if os(visionOS)
                    Button(immersiveSession.isOpen ? "박스 닫기" : "박스 열기") {
                        Task { await toggleImmersiveSpace() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                    #else
                    Text("박스 미리보기는 비전OS에서만 열 수 있습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    #endif
                    Button("조작법") { showOnboarding = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
    }

    #if os(visionOS)
    private func toggleImmersiveSpace() async {
        isBusy = true
        defer { isBusy = false }
        if immersiveSession.isOpen {
            await dismissImmersiveSpace()
            immersiveSession.isOpen = false
        } else if case .opened = await openImmersiveSpace(id: AppScene.immersiveSpaceID) {
            immersiveSession.isOpen = true
        }
    }
    #endif
}

/// 기본은 정적 3D 렌더 썸네일을 작게 보여주고, 시선 포커스·호버일 때만 1.4배로 커지면서
/// 그때만 라이브 3D 모델(`Model3D`)로 바뀌어 드래그 360° 회전을 쓸 수 있다 — 카드 5장이 전부
/// 라이브 모델이면 산만하다는 실기기 영상 확인 후 디자인이 수정한 규칙이다 (결정 36-2).
private struct KartCard: View {
    let kart: KartModel
    let isSelected: Bool

    @State private var isFocused = false
    @State private var rotationDegrees: Double = -20
    @State private var dragStartDegrees: Double = -20

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if isFocused {
                    Model3D(named: kart.usdzResourceName) { model in
                        model
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .rotation3DEffect(.degrees(rotationDegrees), axis: (x: 0, y: 1, z: 0))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                rotationDegrees = dragStartDegrees + value.translation.width * 0.5
                            }
                            .onEnded { _ in
                                dragStartDegrees = rotationDegrees
                            }
                    )
                } else if let thumbnail = loadThumbnail(for: kart) {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(0.6)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            Text(kart.displayName)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.style(StylePalette.uiCyan) : .clear, lineWidth: 2)
        )
        .scaleEffect(isFocused ? 1.4 : 1.0)
        .zIndex(isFocused ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .onHover { hovering in isFocused = hovering }
    }

    /// 썸네일은 Asset Catalog가 아니라 `Resources/KartThumbnails/`에 낱장 PNG로 들어 있어서
    /// `Image(_:)` 이름 조회로는 못 찾는다 — 파일 자체를 읽어서 `Image`로 감싼다.
    private func loadThumbnail(for kart: KartModel) -> Image? {
        guard let url = Bundle.main.url(forResource: "kart_\(kart.id)_thumb", withExtension: "png") else {
            return nil
        }
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(contentsOfFile: url.path) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

/// 조작법 화면: 모드(디오라마/1인칭/3인칭)별로 다른 조작법을 보여준다(결정 39) — 세 모드가
/// 손 제스처 자체를 다르게 쓰기 때문에 하나의 그림 세트로 설명할 수 없다. 첫 실행 시 자동으로
/// 뜨고, "조작법" 버튼으로 다시 볼 수 있다.
private struct OnboardingView: View {
    let onDismiss: () -> Void
    @State private var selectedMode: ExperienceMode = .diorama

    var body: some View {
        VStack(spacing: 20) {
            Text("조작법")
                .font(.title2.bold())

            Picker("모드", selection: $selectedMode) {
                Text("디오라마").tag(ExperienceMode.diorama)
                Text("1인칭").tag(ExperienceMode.firstPerson)
                Text("3인칭").tag(ExperienceMode.thirdPerson)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            GestureInstructionGrid(gestures: GestureInstruction.gestures(for: selectedMode))

            Text(GestureInstruction.footnote(for: selectedMode))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("알겠어요", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

/// 조작법 카드 한 장 = 디자인이 만든 240×240 벡터 그림(`Assets.xcassets/Onboarding/`) + 제목 + 캡션.
/// 그림 파일명·캡션은 디자인 PRD 9장 표와 결정 40번(디자인) 그대로다 — 바꾸면 디자인 쪽
/// `Design/onboarding/_sheet.png`와 어긋나니 같이 고친다.
private struct GestureInstruction: Identifiable {
    let image: String
    let title: String
    let caption: String
    var id: String { image }

    static func gestures(for mode: ExperienceMode) -> [GestureInstruction] {
        switch mode {
        case .diorama:
            // 박스를 밖에서 보며 직접 조종. 전/후진은 핀치를 시작한 손 간격 대비 상대 드래그(결정 39)
            return [
                GestureInstruction(image: "gesture_01_forward", title: "전진", caption: "양손을 핀치한 채로 있으면 전진"),
                GestureInstruction(image: "gesture_02_reverse", title: "후진", caption: "핀치한 채로 양손을 벌리면 후진"),
                GestureInstruction(image: "gesture_03_left", title: "좌회전", caption: "오른손을 떼면(왼손만 핀치) 좌회전"),
                GestureInstruction(image: "gesture_04_right", title: "우회전", caption: "왼손을 떼면(오른손만 핀치) 우회전"),
                GestureInstruction(image: "gesture_05_stop", title: "정지", caption: "양손을 떼면 멈춤"),
            ]
        case .firstPerson:
            // 머리(기기) 방향으로 서서히 조향, 손은 가속만. 그림도 눈이 아니라 헤드셋이다(결정 39 기술 노트)
            return [
                GestureInstruction(image: "gesture_fp_01_steer", title: "조향", caption: "머리가 향하는 쪽으로 서서히 회전"),
                GestureInstruction(image: "gesture_fp_02_throttle", title: "가속", caption: "한쪽 손이라도 핀치하면 가속, 떼면 감속"),
            ]
        case .thirdPerson:
            // 1인칭과 같은 시점, 조향은 한손 핀치. 양손 핀치는 간격과 무관하게 항상 전진(후진 없음)
            return [
                GestureInstruction(image: "gesture_tp_01_forward", title: "전진", caption: "양손을 핀치하면 전진 (후진 없음)"),
                GestureInstruction(image: "gesture_tp_02_left", title: "좌회전", caption: "왼손만 핀치하면 좌회전"),
                GestureInstruction(image: "gesture_tp_03_right", title: "우회전", caption: "오른손만 핀치하면 우회전"),
                GestureInstruction(image: "gesture_tp_04_stop", title: "정지", caption: "양손을 떼면 멈춤"),
            ]
        }
    }

    /// 그림 아래 한 줄 안내. 디오라마의 옛 "양손 사이 약 40 cm = 중립"은 결정 39에서 없어졌다.
    static func footnote(for mode: ExperienceMode) -> String {
        switch mode {
        case .diorama: return "기준은 핀치를 시작한 순간의 손 간격입니다. 그 자리에 두면 전진, 벌리면 후진."
        case .firstPerson: return "조향은 눈동자가 아니라 머리 방향을 따릅니다. 손 간격과 좌우 구분은 쓰지 않습니다."
        case .thirdPerson: return "후진은 없습니다. 양손을 벌려도 계속 전진합니다."
        }
    }
}

private struct GestureInstructionGrid: View {
    let gestures: [GestureInstruction]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
            ForEach(gestures) { gesture in
                VStack(spacing: 8) {
                    Image(gesture.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .accessibilityLabel(gesture.caption)
                    Text(gesture.title)
                        .font(.headline)
                    Text(gesture.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

private struct ColorSwatch: View {
    let color: KartColorOption
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(hex: color.swatchHex))
            .frame(width: 40, height: 40)
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.white.opacity(0.4),
                    lineWidth: isSelected ? 4 : 1.5
                )
            )
    }
}

#Preview {
    ContentView()
        .environment(KartSelectionModel())
        .environment(ImmersiveSessionModel())
}
