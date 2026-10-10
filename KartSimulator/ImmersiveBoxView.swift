#if os(visionOS)
import SwiftUI
import RealityKit
import simd

struct ImmersiveBoxView: View {
    @Environment(KartSelectionModel.self) private var selection

    @State private var rootEntity = Entity()
    @State private var kartSlot = Entity()
    @State private var loadedKartID: String?
    @State private var loadedColorID: String?
    @State private var isLoading = false

    @State private var motion = KartMotionState()
    @State private var inputResolver = HandInputResolver()
    @State private var updateSubscription: Any?

    @State private var track: TrackDefinition?
    @State private var trackPath: TrackPath?
    @State private var lapTracker: LapTracker?
    @State private var offTrackMonitor = OffTrackMonitor()
    @State private var trackDisplayScale: Float = 1
    @State private var trackWorldCenter: SIMD2<Float> = .zero
    @State private var raceModel = RaceModel()

    // RealityKit의 매 프레임 콜백에서 안전하게 쓸 수 있는 평범한 스냅샷. `raceModel`은 HUD가
    // 직접 읽으므로, 프레임 콜백에서 바로 건드리면 "Modifying state during view update"가 난다.
    // 대신 여기 적어두고, 별도 폴링 루프(`runHUDUpdateLoop`)에서 raceModel로 옮긴다.
    @State private var latestDrive: DriveState = .stopped
    @State private var latestLeftStatus = HandStatus(tracked: false, pinching: false)
    @State private var latestRightStatus = HandStatus(tracked: false, pinching: false)
    @State private var latestSpeed: Float = 0
    @State private var latestLapProgress = LapProgress()
    @State private var latestCheckpointCount = 0
    @State private var latestIsOffTrack = false

    private let boxSize: SIMD3<Float> = [0.7, 0.4, 0.7]
    private let boxPosition: SIMD3<Float> = [0, 1.05, -1.1]
    /// 박스 바닥에서 트랙 전체(바운딩 박스)가 차지할 폭. 나머지는 여백.
    private let trackFootprint: Float = 0.6

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
            loadTrack(into: rootEntity)

            updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                tickMotion(deltaTime: Float(event.deltaTime))
            }
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
        .gesture(driveGesture)
        .overlay(alignment: .top) {
            RaceHUDOverlay(hud: raceModel.hud)
                .padding(.top, 48)
        }
        .task {
            await runHUDUpdateLoop()
        }
    }

    /// `raceModel`(HUD가 읽는 Observable) 갱신을 RealityKit 프레임 콜백과 분리된 주기로 돌린다.
    ///
    /// 알려진 한계: 이머시브 스페이스가 열려 있는 동안은 RealityView가 계속(90Hz) 렌더링 중이라
    /// "뷰 업데이트 중이 아닌 시점"이 사실상 없고, 그 안에서 `@Observable` 상태를 일반 `.overlay()`로
    /// 보여주면 타이밍에 상관없이 "Modifying state during view update" 경고가 난다(크래시는 아니고
    /// HUD 값 자체는 정상 갱신됨). 간격을 늘려 로그 노이즈만 줄였고, 정식 해결책은 M5에서 HUD를
    /// RealityView의 3D attachment(entity에 붙는 SwiftUI 뷰)로 바꿀 때 함께 적용한다.
    private let hudUpdateInterval = Duration.milliseconds(250)

    private func runHUDUpdateLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: hudUpdateInterval)
            raceModel.updateDrive(latestDrive, left: latestLeftStatus, right: latestRightStatus)
            raceModel.updateMotion(speedMetersPerSecond: latestSpeed, deltaTime: 0.25)
            raceModel.updateLap(latestLapProgress, totalCheckpoints: latestCheckpointCount)
            raceModel.setRespawning(latestIsOffTrack)
        }
    }

    /// M2 입력 프로토타입: SpatialEventGesture로 받은 핀치를 HandInputResolver에 넘긴다.
    private var driveGesture: some Gesture {
        SpatialEventGesture()
            .onChanged { events in ingest(events, isEnding: false) }
            .onEnded { events in ingest(events, isEnding: true) }
    }

    private func ingest(_ events: SpatialEventCollection, isEnding: Bool) {
        for event in events {
            guard let chirality = event.chirality else { continue }
            let hand: HandChirality = chirality == .left ? .left : .right
            let pinching = !isEnding && event.phase == .active
            let location = event.location3D
            let position = SIMD3<Float>(Float(location.x), Float(location.y), Float(location.z))
            inputResolver.ingest(HandSample(chirality: hand, isPinching: pinching, position: position, timestamp: event.timestamp))
        }
    }

    /// `Tracks/track_01.json`(앱 번들에 복사된 사본)을 읽어 월드→박스 배율을 계산하고,
    /// path를 따라 간단한 점열 시각화를 깔아 둔다. 실제 타일 3D 에셋은 M3 이후(디자인 전달 후).
    @MainActor
    private func loadTrack(into parent: Entity) {
        guard let url = Bundle.main.url(forResource: "track_01", withExtension: "json") else {
            print("트랙 리소스를 찾을 수 없습니다: track_01.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let definition = try JSONDecoder().decode(TrackDefinition.self, from: data)
            let path = TrackPath(definition)

            let xs = path.points.map(\.x)
            let zs = path.points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minZ = zs.min(), let maxZ = zs.max() else { return }
            let worldSpan = max(maxX - minX, max(maxZ - minZ, 0.001))

            track = definition
            trackPath = path
            lapTracker = LapTracker(track: definition)
            trackDisplayScale = trackFootprint / worldSpan
            trackWorldCenter = SIMD2((minX + maxX) / 2, (minZ + maxZ) / 2)

            parent.addChild(buildTrackVisual(definition: definition, path: path))

            let startPoint = path.points[definition.start.pathIndex]
            motion = KartMotionState(
                speed: 0,
                heading: definition.start.heading,
                position: SIMD3(startPoint.x, 0, startPoint.y)
            )
            raceModel.start(totalLaps: definition.laps)
        } catch {
            print("트랙 로드 실패: \(error)")
        }
    }

    @MainActor
    private func buildTrackVisual(definition: TrackDefinition, path: TrackPath) -> Entity {
        let root = Entity()
        let pathMaterial = UnlitMaterial(color: .init(white: 0.7, alpha: 1))
        let startMaterial = UnlitMaterial(color: .systemBlue)
        let markerSize: Float = 0.006
        let floorY = -boxSize.y / 2 + 0.011

        for point in path.points {
            let display = worldToDisplay(SIMD2(point.x, point.y))
            let marker = ModelEntity(mesh: .generateBox(size: markerSize), materials: [pathMaterial])
            marker.position = SIMD3(display.x, floorY, display.y)
            root.addChild(marker)
        }

        let startPoint = path.points[definition.start.pathIndex]
        let startDisplay = worldToDisplay(SIMD2(startPoint.x, startPoint.y))
        let startMarker = ModelEntity(mesh: .generateSphere(radius: markerSize), materials: [startMaterial])
        startMarker.position = SIMD3(startDisplay.x, floorY + 0.003, startDisplay.y)
        root.addChild(startMarker)

        return root
    }

    /// 트랙 월드 좌표(XZ, 미터)를 박스 바닥의 표시 좌표로 변환한다.
    private func worldToDisplay(_ worldXZ: SIMD2<Float>) -> SIMD2<Float> {
        (worldXZ - trackWorldCenter) * trackDisplayScale
    }

    @MainActor
    private func tickMotion(deltaTime: Float) {
        guard deltaTime > 0, let track, let trackPath, let lapTracker else { return }

        let now = Date().timeIntervalSinceReferenceDate
        let (drive, leftStatus, rightStatus) = inputResolver.resolve(now: now)
        let tuning = MotionTuning().applying(track.tuning)
        motion = motion.advancing(drive: drive, tuning: tuning, deltaTime: deltaTime)

        let positionXZ = SIMD2(motion.position.x, motion.position.z)
        let (pathIndex, distanceFromCenterline) = trackPath.closestSegment(to: positionXZ)
        lapTracker.update(pathIndex: pathIndex)

        let isOffTrack = distanceFromCenterline > (track.width / 2 + 0.5)
        offTrackMonitor.update(isOffTrack: isOffTrack, deltaTime: TimeInterval(deltaTime), threshold: tuning.offTrackRespawn)

        latestDrive = drive
        latestLeftStatus = leftStatus
        latestRightStatus = rightStatus
        latestSpeed = motion.speed
        latestLapProgress = lapTracker.progress
        latestCheckpointCount = track.checkpoints.count
        latestIsOffTrack = isOffTrack

        if offTrackMonitor.shouldRespawn {
            let startPoint = trackPath.points[track.start.pathIndex]
            motion = KartMotionState(
                speed: tuning.respawnSpeed,
                heading: track.start.heading,
                position: SIMD3(startPoint.x, 0, startPoint.y)
            )
            lapTracker.resetPosition(pathIndex: track.start.pathIndex)
            offTrackMonitor.acknowledgeRespawn()
        }

        let display = worldToDisplay(positionXZ)
        kartSlot.position.x = display.x
        kartSlot.position.z = display.y
        kartSlot.orientation = simd_quatf(angle: motion.heading, axis: [0, 1, 0])
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
            KartFitter.fit(entity, scale: trackDisplayScale)

            kartSlot.children.removeAll()
            kartSlot.addChild(entity)

            loadedKartID = kart.id
            loadedColorID = colorID
        } catch {
            print("카트 로드 실패(\(kart.usdzResourceName)): \(error)")
        }
    }
}

/// M5 HUD의 1차 데이터 플러밍 — 배치/스타일은 디자인 전달 후 다듬는다 (`Docs/TechTask.md` M5).
private struct RaceHUDOverlay: View {
    let hud: RaceHUDState

    var body: some View {
        VStack(spacing: 4) {
            Text("LAP \(hud.lap) / \(hud.totalLaps)")
                .font(.headline)
            Text(String(format: "%.1f s", hud.lapTime))
                .font(.title2.monospacedDigit())
            Text(String(format: "%.0f km/h", hud.speedKmh))
                .font(.subheadline.monospacedDigit())
            if hud.respawning {
                Text("트랙 이탈")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
