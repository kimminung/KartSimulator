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

    private let boxSize: SIMD3<Float> = [0.7, 0.4, 0.7]
    private let boxPosition: SIMD3<Float> = [0, 1.05, -1.1]

    /// Scaled down from the tech PRD's full-size MotionTuning so the kart stays visible
    /// driving laps inside this small box prototype, ahead of real track tiles (M3).
    private let motionTuning = MotionTuning(
        maxSpeed: 0.3,
        accel: 0.25,
        coastDecel: 0.2,
        brakeDecel: 0.4,
        turnRateLow: 140,
        turnRateHigh: 90,
        minTurnSpeed: 0.02
    )

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

    /// M2 입력 프로토타입: SpatialEventGesture로 받은 핀치를 HandInputResolver에 넘기고,
    /// 매 프레임 KartMotionState로 박스 안에서 카트를 실제로 움직여 본다 (트랙 타일 없이).
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

    @MainActor
    private func tickMotion(deltaTime: Float) {
        guard deltaTime > 0 else { return }
        let now = Date().timeIntervalSinceReferenceDate
        let (drive, _, _) = inputResolver.resolve(now: now)
        motion = motion.advancing(drive: drive, tuning: motionTuning, deltaTime: deltaTime)

        // No track tiles yet (M3) — bounce off the box floor's edges so the kart stays inside.
        let halfExtentX = boxSize.x * 0.96 / 2 - 0.03
        let halfExtentZ = boxSize.z * 0.96 / 2 - 0.03
        if motion.position.x > halfExtentX || motion.position.x < -halfExtentX {
            motion.heading = -motion.heading
            motion.position.x = min(max(motion.position.x, -halfExtentX), halfExtentX)
        }
        if motion.position.z > halfExtentZ || motion.position.z < -halfExtentZ {
            motion.heading = .pi - motion.heading
            motion.position.z = min(max(motion.position.z, -halfExtentZ), halfExtentZ)
        }

        kartSlot.position.x = motion.position.x
        kartSlot.position.z = motion.position.z
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
