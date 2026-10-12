#if os(iOS)
import RealityKit
import SwiftUI

/// iOS/iPadOS 전체 화면 레이스(결정 60). 가상 카메라 `RealityView` 위에 HUD·2D 미니맵·터치 존을 겹친다.
/// 조작은 핀치 규칙 1:1(`TouchInputResolver`): 왼쪽/오른쪽 반 = 왼손/오른손 핀치.
struct RaceScreen: View {
    @Environment(KartSelectionModel.self) private var selection
    @Environment(\.dismiss) private var dismiss
    @State private var controller: RaceSceneController?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let controller {
                    RealityView { content in
                        await controller.setup(content: &content)
                    } update: { content in
                        controller.applyCameraMode(content: &content)
                    }
                    .ignoresSafeArea()
                    .onChange(of: proxy.size, initial: true) { _, size in
                        controller.aspect = Float(size.width / max(size.height, 1))
                    }

                    touchZones(controller)
                    overlays(controller)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            if controller == nil { controller = RaceSceneController(selection: selection) }
        }
        .onDisappear { controller?.teardown() }
    }

    // MARK: - 터치 존(왼손/오른손 핀치)

    private func touchZones(_ controller: RaceSceneController) -> some View {
        // 위쪽 140 pt(HUD·시점·일시정지·닫기)는 비워 둔다 — 터치 존이 겹치면 세그먼트 컨트롤의 짧은 탭을 가로챘다(시뮬레이터 확인).
        HStack(spacing: 0) {
            thumbZone(label: "왼손 · 좌회전") { side in controller.touch.left = side }
            thumbZone(label: "오른손 · 우회전") { side in controller.touch.right = side }
        }
        .padding(.top, 140)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityHint("양쪽을 누르면 전진, 누른 채 아래로 끌면 후진, 한쪽만 누르면 그쪽으로 회전")
    }

    private func thumbZone(label: String, update: @escaping (TouchInputResolver.Side) -> Void) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in update(.init(isDown: true, dragDown: Float(value.translation.height))) }
                    .onEnded { _ in update(.init()) }
            )
            .accessibilityLabel(label)
    }

    // MARK: - HUD

    @ViewBuilder
    private func overlays(_ controller: RaceSceneController) -> some View {
        let hud = controller.raceModel.hud
        VStack {
            HStack(alignment: .top) {
                hudPanel(hud)
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Picker("시점", selection: Binding(get: { controller.cameraMode }, set: { controller.setCameraMode($0) })) {
                        Text("탑뷰").tag(CameraViewMode.topView)
                        Text("추적").tag(CameraViewMode.chase)
                        Text("AR").tag(CameraViewMode.ar)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .padding(4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    HStack {
                        if hud.phase == .racing {
                            Button("일시정지") { controller.pause() }
                        }
                        Button("닫기") { dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.style(StylePalette.uiPanel).opacity(0.85))
                    .foregroundStyle(Color.style(StylePalette.uiInk))
                }
                .preferredColorScheme(.dark)
            }
            .padding()
            Spacer()
            HStack(alignment: .bottom) {
                PinchHintView(left: hud.left.pinching, right: hud.right.pinching, drive: hud.drive)
                Spacer()
                if let track = controller.track {
                    TrackPlanCanvas(
                        track: track, flipped: false,
                        kart: (SIMD2(controller.displayPose.position.x, controller.displayPose.position.z), controller.displayPose.heading),
                        checkpointsPassed: controller.displayCheckpoints
                    )
                    .frame(width: 130, height: 130)
                    .background(Color.style(track.theme?.minimap?.disc ?? StylePalette.uiPanel).opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("미니맵")
                }
            }
            .padding()
        }
        .allowsHitTesting(true)

        // 카운트다운 숫자는 장면 안 3D 텍스트(`RaceSceneController.showCountdown`)로 그린다. 여기서는 VoiceOver용 라벨만 둔다.
        if let text = countdownText(hud, go: controller.showsGoFlash) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityLabel(text == "GO" ? "출발" : "카운트다운 \(text)")
        }
        if hud.phase == .paused {
            pausePanel(controller, hud)
        }
        if let result = controller.raceResult, hud.phase == .finished {
            resultPanel(controller, result)
        }
        if let error = controller.loadError {
            // 미니맵(오른쪽 아래)과 겹치지 않게 화면 가운데 아래쪽에 띄운다.
            Text(error)
                .font(.footnote)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 260)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 170)
                .allowsHitTesting(false)
        }
    }

    private func countdownText(_ hud: RaceHUDState, go: Bool) -> String? {
        if go { return "GO" }
        if case .countdown(let n) = hud.phase { return "\(n)" }
        return nil
    }

    private func hudPanel(_ hud: RaceHUDState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LAP \(hud.lap) / \(hud.totalLaps)")
                .font(.headline)
            Text(formatRaceTime(hud.lapTime))
                .font(.title2.monospacedDigit())
            HStack(spacing: 8) {
                Text("총 " + formatRaceTime(hud.totalTime))
                if let best = hud.bestLapTime { Text("BEST " + formatRaceTime(best)) }
            }
            .font(.caption.monospacedDigit())
            .opacity(0.8)
            Text(String(format: "%.0f km/h", hud.speedKmh))
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(Color.style(StylePalette.uiInk))
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func pausePanel(_ controller: RaceSceneController, _ hud: RaceHUDState) -> some View {
        VStack(spacing: 12) {
            Text("일시정지")
                .font(.custom("Galmuri11-Bold", size: 28, relativeTo: .title))
            Text("LAP \(hud.lap) / \(hud.totalLaps) · " + formatRaceTime(hud.totalTime))
                .font(.caption.monospacedDigit())
            HStack(spacing: 12) {
                Button("재개") { controller.resume() }
                    .buttonStyle(.borderedProminent)
                Button("다시 시작") { controller.restart() }
                    .buttonStyle(.bordered)
                Button("닫기") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultPanel(_ controller: RaceSceneController, _ result: RaceResult) -> some View {
        VStack(spacing: 8) {
            Text("완주!")
                .font(.custom("Galmuri11-Bold", size: 28, relativeTo: .title))
            Text(formatRaceTime(result.totalTime))
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
            if result.isNewRecord {
                Text("신기록!")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.style(StylePalette.uiGold), in: Capsule())
                    .foregroundStyle(Color.style(StylePalette.uiNight))
            } else if let previous = result.previousBestTotalTime {
                Text("BEST " + formatRaceTime(previous)).font(.caption.monospacedDigit())
            }
            ForEach(Array(result.lapTimes.enumerated()), id: \.offset) { index, lap in
                HStack {
                    Text("LAP \(index + 1)")
                    Spacer(minLength: 16)
                    Text(formatRaceTime(lap))
                        .foregroundStyle(lap == result.bestLapTime ? Color.style(StylePalette.uiCyan) : .primary)
                }
                .font(.caption.monospacedDigit())
                .frame(width: 160)
            }
            Text("\(result.kartName) · \(result.trackName)")
                .font(.caption2)
                .opacity(0.7)
            HStack(spacing: 12) {
                Button("다시 하기") { controller.restart() }
                    .buttonStyle(.borderedProminent)
                Button("트랙 선택") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 양손(양쪽 엄지) 상태 표시: visionOS HUD의 핀치 점과 같은 뜻.
private struct PinchHintView: View {
    let left: Bool
    let right: Bool
    let drive: DriveState

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(left ? Color.style(StylePalette.uiCyan) : Color.white.opacity(0.3)).frame(width: 14, height: 14)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(Color.style(StylePalette.uiInk))
            Circle().fill(right ? Color.style(StylePalette.uiCyan) : Color.white.opacity(0.3)).frame(width: 14, height: 14)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel("조작 상태 \(label)")
    }

    private var label: String {
        switch drive {
        case .pedal(let v): return v >= 0 ? "전진" : "후진"
        case .turnLeft: return "좌회전"
        case .turnRight: return "우회전"
        case .stopped: return "정지"
        case .waiting: return "대기"
        }
    }
}
#endif
