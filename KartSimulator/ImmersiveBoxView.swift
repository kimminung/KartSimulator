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
        let (drive, _, _) = inputResolver.resolve(now: now)
        let tuning = MotionTuning().applying(track.tuning)
        motion = motion.advancing(drive: drive, tuning: tuning, deltaTime: deltaTime)

        let positionXZ = SIMD2(motion.position.x, motion.position.z)
        let (pathIndex, distanceFromCenterline) = trackPath.closestSegment(to: positionXZ)
        lapTracker.update(pathIndex: pathIndex)

        let isOffTrack = distanceFromCenterline > (track.width / 2 + 0.5)
        offTrackMonitor.update(isOffTrack: isOffTrack, deltaTime: TimeInterval(deltaTime), threshold: tuning.offTrackRespawn)

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
#endif
