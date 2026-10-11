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

            Group {
                switch selectedMode {
                case .diorama: DioramaOnboardingContent()
                case .firstPerson: FirstPersonOnboardingContent()
                case .thirdPerson: ThirdPersonOnboardingContent()
                }
            }

            Button("알겠어요", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

/// 박스를 밖에서 보며 카트를 직접 조종한다(결정 39) — 손 그림 5장은 디자인이 이미 만들어 둔
/// `Assets.xcassets/Onboarding/` 벡터 이미지를 그대로 쓰되, 캡션만 새 제스처(상대 거리 드래그)에
/// 맞게 고쳤다.
private struct DioramaOnboardingContent: View {
    private let gestures: [(image: String, title: String, caption: String)] = [
        ("gesture_01_forward", "전진", "양손을 핀치한 채로 있으면 전진"),
        ("gesture_02_reverse", "후진", "핀치한 채로 양손을 벌리면 후진"),
        ("gesture_03_left", "좌회전", "오른손을 떼면(왼손만 핀치) 좌회전"),
        ("gesture_04_right", "우회전", "왼손을 떼면(오른손만 핀치) 우회전"),
        ("gesture_05_stop", "정지", "양손을 떼면 멈춤"),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
            ForEach(gestures, id: \.image) { gesture in
                VStack(spacing: 8) {
                    Image(gesture.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
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

/// 1인칭: 바라보는 방향(정확히는 머리 방향)으로 조향, 손은 가속 여부만 맡는다(결정 39).
/// 디자인이 아직 전용 그림을 안 만들어서 SF Symbols로 자리만 잡아 둔다.
private struct FirstPersonOnboardingContent: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
            SymbolInstructionCard(symbolName: "eye.fill", title: "조향", caption: "바라보는 방향으로 카트가 서서히 돕니다")
            SymbolInstructionCard(symbolName: "hand.point.up.braille.fill", title: "가속", caption: "한쪽 손이라도 핀치하고 있으면 가속, 떼면 감속")
        }
    }
}

/// 3인칭: 1인칭과 같은 시점이지만, 조향은 이 프로젝트가 맨 처음 썼던 한손 핀치 좌/우회전
/// 방식으로 돌아간다(후진 없음, 결정 39).
private struct ThirdPersonOnboardingContent: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
            SymbolInstructionCard(symbolName: "hand.raised.fill", title: "전진", caption: "양손을 핀치하면 전진")
            SymbolInstructionCard(symbolName: "arrowshape.turn.up.left.fill", title: "좌회전", caption: "왼손만 핀치하면 좌회전")
            SymbolInstructionCard(symbolName: "arrowshape.turn.up.right.fill", title: "우회전", caption: "오른손만 핀치하면 우회전")
            SymbolInstructionCard(symbolName: "stop.fill", title: "정지", caption: "양손을 떼면 멈춤")
        }
    }
}

private struct SymbolInstructionCard: View {
    let symbolName: String
    let title: String
    let caption: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 40))
                .frame(width: 120, height: 120)
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
