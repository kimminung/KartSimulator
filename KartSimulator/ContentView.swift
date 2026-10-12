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
                    Text("핀치 로버") // 앱 이름 확정: 핀치 로버 / Pinch Rover (결정 53, Issue #30)
                        // 제목에만 픽셀 폰트(Galmuri) 적용 — 본문/숫자/라벨은 시스템 폰트 유지 (디자인 결정 20-3·20-5).
                        .font(.custom("Galmuri11-Bold", size: 40, relativeTo: .largeTitle))
                    Text("카트를 고르고 박스 안에서 확인해 보세요.")
                        .foregroundStyle(.secondary)
                }

                // 트랙 카드 3장(Issue #43, 디자인 목업 01): 경로 썸네일·이름·난이도 점·선택한 카트의 최고 기록.
                VStack(alignment: .leading, spacing: 8) {
                    Text("트랙")
                        .font(.headline)
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(TrackCatalog.tracks, id: \.id) { track in
                            TrackCard(
                                track: track,
                                isSelected: track.id == selection.selectedTrackID,
                                bestTotalTime: TrackCatalog.bestTotalTime(trackID: track.id, kartID: selection.selectedKartID)
                            )
                            .onTapGesture { selection.selectedTrackID = track.id }
                        }
                    }
                }

                Text("카트")
                    .font(.headline)
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

                // 제3자 크레딧(LICENSE 5조): Galmuri는 OFL 1.1이라 앱 안 표기가 필요하다(Issue #31).
                Text("Galmuri 폰트 © 2019–2025 Lee Minseo (quiple), SIL Open Font License 1.1 · 미니맵 받침 © Apple (Diorama 샘플)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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

/// 트랙 카드(목업 01): 어두운 우물 위에 중심선을 두 겹(테두리 `mm-edge` + 노면 `mm-road`)으로 그리고 출발점에 `ui-sky` 점,
/// 이름, 난이도 점 5개 중 n개(`ui-gold`), "최고 m:ss.xx"(선택한 카트 기준, 없으면 "—").
private struct TrackCard: View {
    let track: TrackDefinition
    let isSelected: Bool
    let bestTotalTime: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TrackThumbnail(track: track)
                .frame(width: 120, height: 120)
                .background(Color.style(StylePalette.uiWell).opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
            Text(track.name)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < TrackCatalog.difficultyDots(track.difficulty) ? Color.style(StylePalette.uiGold) : Color.white.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityLabel("난이도 \(TrackCatalog.difficultyDots(track.difficulty)) / 5")
            Text("최고 " + (bestTotalTime.map(formatRaceTime) ?? "—"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.style(StylePalette.uiCyan) : .clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .hoverEffect()
    }
}

/// 트랙 JSON의 `path`(중심선, 미터)를 카드 안에 맞춰 그린다. 디오라마 표시(`ScenePlacement` 씬 yaw π, 결정 43·44)와 같은 방향이 되도록
/// 위아래·좌우를 뒤집어 두어 박스에서 보는 모양과 카드가 일치한다.
private struct TrackThumbnail: View {
    let track: TrackDefinition

    var body: some View {
        Canvas { context, size in
            let points = track.path.map(\.vector)
            guard points.count > 2,
                  let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minZ = points.map(\.y).min(), let maxZ = points.map(\.y).max() else { return }
            let inset: CGFloat = 16
            let span = CGFloat(max(maxX - minX, maxZ - minZ, 0.001))
            let scale = (min(size.width, size.height) - inset * 2) / span
            let offsetX = (size.width - CGFloat(maxX - minX) * scale) / 2
            let offsetY = (size.height - CGFloat(maxZ - minZ) * scale) / 2
            func point(_ p: SIMD2<Float>) -> CGPoint {
                // 박스는 트랙을 180° 돌려 보여 준다(결정 43): x·z 둘 다 뒤집는다. z는 화면 아래가 +z.
                CGPoint(x: size.width - (offsetX + CGFloat(p.x - minX) * scale),
                        y: size.height - (offsetY + CGFloat(p.y - minZ) * scale))
            }
            var path = Path()
            path.move(to: point(points[0]))
            for p in points.dropFirst() { path.addLine(to: point(p)) }
            path.closeSubpath()
            let roadWidth = max(CGFloat(track.width) * scale, 4)
            context.stroke(path, with: .color(Color.style(StylePalette.mmEdge)), style: StrokeStyle(lineWidth: roadWidth * 1.5, lineJoin: .round))
            context.stroke(path, with: .color(Color.style(StylePalette.mmRoad)), style: StrokeStyle(lineWidth: roadWidth, lineJoin: .round))
            let start = point(points[min(track.start.pathIndex, points.count - 1)])
            let dot = CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dot), with: .color(Color.style(StylePalette.uiSky)))
        }
    }
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

    /// 두 모드의 손 조작은 완전히 같다(결정 49, Issue #24): 그림 한 벌(디오라마 5장)을 같이 쓴다.
    static func gestures(for mode: ExperienceMode) -> [GestureInstruction] {
        [
            GestureInstruction(image: "gesture_01_forward", title: "전진", caption: "양손을 핀치한 채로 있으면 전진"),
            GestureInstruction(image: "gesture_02_reverse", title: "후진", caption: "핀치한 채로 양손을 벌리면 후진"),
            GestureInstruction(image: "gesture_03_left", title: "좌회전", caption: "오른손을 떼면(왼손만 핀치) 좌회전"),
            GestureInstruction(image: "gesture_04_right", title: "우회전", caption: "왼손을 떼면(오른손만 핀치) 우회전"),
            GestureInstruction(image: "gesture_05_stop", title: "정지", caption: "양손을 떼면 멈춤"),
        ]
    }

    /// 그림 아래 한 줄 안내. 옛 "양손 사이 약 40 cm = 중립"은 결정 39에서 없어졌다.
    static func footnote(for mode: ExperienceMode) -> String {
        switch mode {
        case .diorama: return "기준은 핀치를 시작한 순간의 손 간격입니다. 그 자리에 두면 전진, 벌리면 후진."
        case .thirdPerson: return "조작은 디오라마와 같습니다. 시점은 카트 뒤에서 카트가 가는 쪽을 보고, 고개는 자유롭게 돌려도 됩니다."
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
