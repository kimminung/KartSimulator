#if os(visionOS)
import SwiftUI
import RealityKit
import ARKit
import simd

struct ImmersiveBoxView: View {
    @Environment(KartSelectionModel.self) private var selection

    @State private var rootEntity = Entity()
    @State private var kartSlot = Entity()
    @State private var inputCatcher = Entity()
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

    // MARK: - 디버그 전용 (실기기 제스처 문제 진단용, `Docs/decisions.md` 21번 참고)
    // 헤드 앵커 위치에 구슬, 시선(기기 정면) 방향으로 막대를 띄워 "내가 어디를 보고 있는지"를
    // 눈으로 확인할 수 있게 한다. 원인 파악 끝나면 이 섹션과 관련 코드는 통째로 지운다.
    @State private var headMarker = Entity()
    @State private var gazeRay = Entity()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var arSession = ARKitSession()
    private let gazeRayLength: Float = 3.0

    // MARK: - 디버그 전용: 주행 경로(빨간 선) + 이동량 로그 (`Docs/decisions.md` 23번 참고)
    @State private var trailRoot = Entity()
    @State private var lastTrailDisplayPoint: SIMD2<Float>?
    @State private var totalDistanceTraveled: Float = 0
    @State private var motionLogAccumulator: Float = 0
    /// 박스 바닥 기준 이 거리 이상 움직였을 때만 새 선 조각을 추가한다(매 프레임 추가하면 세그먼트가 과도하게 늘어난다).
    private let trailMinSegmentLength: Float = 0.003
    private let motionLogInterval: Float = 0.25

    private let boxSize: SIMD3<Float> = [0.7, 0.4, 0.7]
    private let boxPosition: SIMD3<Float> = [0, 1.05, -1.1]
    /// HUD(속도/랩 표시)를 발밑이 아니라 박스 바로 위에 띄우기 위한 위치.
    private var hudPosition: SIMD3<Float> {
        boxPosition + SIMD3(0, boxSize.y / 2 + 0.15, 0)
    }
    /// 박스 바닥에서 트랙 전체(바운딩 박스)가 차지할 폭. 나머지는 여백.
    private let trackFootprint: Float = 0.6
    /// 트랙 배율과 무관하게 카트가 항상 눈에 보이는 크기를 갖도록 고정한다 (박스 0.7m 기준 장난감 카트 크기).
    private let kartVisualLength: Float = 0.12

    var body: some View {
        RealityView { content, attachments in
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

            // 디버그: 카트가 실제로 지나간 경로를 빨간 선으로 남긴다. rootEntity 로컬 좌표(박스 기준)에 쌓는다.
            rootEntity.addChild(trailRoot)

            // 핀치 제스처를 받으려면 InputTargetComponent + CollisionComponent가 있는 엔티티가
            // 필요하다(없으면 SpatialEventGesture가 아무것도 조준하지 못해 완전히 무반응이다).
            // 박스보다 넉넉하게 잡아 시선이 박스 언저리만 향해도 핀치가 잡히게 한다.
            inputCatcher.position = boxPosition
            inputCatcher.components.set(CollisionComponent(shapes: [.generateBox(size: boxSize * 3)]))
            inputCatcher.components.set(InputTargetComponent())
            content.add(inputCatcher)

            content.add(rootEntity)
            loadTrack(into: rootEntity)

            // 디버그: 헤드 위치 구슬 + 시선 방향 막대. world 좌표계에 바로 두므로 rootEntity가 아니라
            // content에 직접 추가한다 (rootEntity는 박스 위치로 옮겨져 있어 기준이 다르다).
            let headMaterial = UnlitMaterial(color: .yellow)
            let headModel = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [headMaterial])
            headMarker.addChild(headModel)
            content.add(headMarker)

            let rayMaterial = UnlitMaterial(color: .green)
            let rayModel = ModelEntity(
                mesh: .generateBox(size: SIMD3(0.004, 0.004, gazeRayLength)),
                materials: [rayMaterial]
            )
            gazeRay.addChild(rayModel)
            content.add(gazeRay)

            if WorldTrackingProvider.isSupported {
                Task {
                    do {
                        try await arSession.run([worldTracking])
                    } catch {
                        print("DEBUG-GAZE ARKitSession 시작 실패: \(error)")
                    }
                }
            } else {
                print("DEBUG-GAZE 이 기기/시뮬레이터는 WorldTrackingProvider를 지원하지 않습니다.")
            }

            // HUD(속도/랩)를 2D `.overlay()`가 아니라 3D attachment로 박스 바로 위에 띄운다.
            // `.overlay()`는 이머시브 스페이스 안에서는 뷰포트 기준이 아니라 엉뚱한 위치(발밑 근처)에
            // 떠 버리는 문제가 있었다 — attachment는 다른 엔티티처럼 월드 좌표에 직접 배치할 수 있다.
            if let hudAttachment = attachments.entity(for: "hud") {
                hudAttachment.position = hudPosition
                hudAttachment.components.set(BillboardComponent())
                content.add(hudAttachment)
            }

            updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                tickMotion(deltaTime: Float(event.deltaTime))
                updateHeadDebugGizmo()
            }
        } update: { _, _ in
            guard !isLoading,
                  loadedKartID != selection.selectedKartID || loadedColorID != selection.selectedColorID
            else { return }

            isLoading = true
            Task {
                await loadKart()
                isLoading = false
            }
        } attachments: {
            Attachment(id: "hud") {
                RaceHUDOverlay(hud: raceModel.hud)
            }
        }
        .gesture(driveGesture)
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
    /// `inputCatcher`를 조준해야만 이벤트가 들어온다(RealityKit 제스처는 InputTargetComponent +
    /// CollisionComponent가 있는 엔티티를 봐야만 발생한다).
    private var driveGesture: some Gesture {
        SpatialEventGesture()
            .targetedToEntity(inputCatcher)
            .onChanged { value in ingest(value.gestureValue, isEnding: false) }
            .onEnded { value in ingest(value.gestureValue, isEnding: true) }
    }

    private func ingest(_ events: SpatialEventCollection, isEnding: Bool) {
        // 디버그: 이벤트가 아예 안 들어오는지, chirality가 없어서 걸러지는지, 왼/오 각각 어떻게
        // 들어오는지 전부 로그로 남긴다. 원인 파악 끝나면 이 print들은 지운다 (Docs/decisions.md 21번).
        if events.isEmpty {
            print("DEBUG-GESTURE ingest 호출됐지만 이벤트 0개 (isEnding=\(isEnding))")
        }
        for event in events {
            guard let chirality = event.chirality else {
                print("DEBUG-GESTURE chirality 없음 — phase=\(event.phase), location=\(event.location3D)")
                continue
            }
            let hand: HandChirality = chirality == .left ? .left : .right
            let pinching = !isEnding && event.phase == .active
            let location = event.location3D
            let position = SIMD3<Float>(Float(location.x), Float(location.y), Float(location.z))
            print("DEBUG-GESTURE \(hand == .left ? "LEFT" : "RIGHT") phase=\(event.phase) pinching=\(pinching) pos=\(position)")
            // `event.timestamp`는 SwiftUI 제스처 전용 시계라 `tickMotion`의 `now`(CACurrentMediaTime)와
            // 기준 시점이 다르다. 두 값을 그대로 비교하면 항상 "스테일"로 판정돼 `HandInputResolver`가
            // 영원히 .stopped만 반환한다(실기기에서 "차가 안 움직인다"의 진짜 원인, 결정 24번 참고).
            // 받는 즉시 같은 시계(CACurrentMediaTime)로 다시 찍어서 넘긴다.
            inputResolver.ingest(HandSample(chirality: hand, isPinching: pinching, position: position, timestamp: CACurrentMediaTime()))
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

    /// 디버그 전용: 박스 바닥 표시 좌표 두 점을 빨간 막대 하나로 이어 붙인다(경로 누적용).
    @MainActor
    private func addTrailSegment(from a: SIMD2<Float>, to b: SIMD2<Float>) {
        let floorY = -boxSize.y / 2 + 0.013
        let start = SIMD3<Float>(a.x, floorY, a.y)
        let end = SIMD3<Float>(b.x, floorY, b.y)
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0001 else { return }

        let material = UnlitMaterial(color: .red)
        let segment = ModelEntity(
            mesh: .generateBox(size: SIMD3(0.003, 0.003, length)),
            materials: [material]
        )
        segment.position = (start + end) / 2
        segment.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(delta))
        trailRoot.addChild(segment)
    }

    /// 디버그 전용: 헤드 앵커 위치에 구슬을, 기기 정면 방향으로 막대를 띄운다.
    @MainActor
    private func updateHeadDebugGizmo() {
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }
        let transform = anchor.originFromAnchorTransform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        // 디바이스 로컬 -Z가 정면이다(RealityKit/ARKit 공통 관례).
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let direction = simd_normalize(forward)

        headMarker.position = position
        gazeRay.position = position + direction * (gazeRayLength / 2)
        gazeRay.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
    }

    @MainActor
    private func tickMotion(deltaTime: Float) {
        guard deltaTime > 0, let track, let trackPath, let lapTracker else { return }

        // `ingest()`에서 찍는 시계(CACurrentMediaTime)와 반드시 같은 기준이어야 한다. 섞어 쓰면
        // HandInputResolver의 스테일 판정이 항상 틀어진다(결정 24번).
        let now = CACurrentMediaTime()
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

        // 디버그: 실제로 이동한 거리를 빨간 선으로 쌓고, 콘솔에도 주기적으로 남긴다.
        if let last = lastTrailDisplayPoint {
            if simd_distance(last, display) >= trailMinSegmentLength {
                addTrailSegment(from: last, to: display)
                lastTrailDisplayPoint = display
            }
        } else {
            lastTrailDisplayPoint = display
        }

        totalDistanceTraveled += motion.speed * deltaTime
        motionLogAccumulator += deltaTime
        if motionLogAccumulator >= motionLogInterval {
            motionLogAccumulator = 0
            print("DEBUG-MOTION drive=\(drive) speed=\(motion.speed)m/s pos=\(motion.position) totalDistance=\(totalDistanceTraveled)m")
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
            // 트랙 전체를 박스에 맞추는 배율(trackDisplayScale)을 카트에도 그대로 쓰면 트랙이 넓을수록
            // 카트가 같이 작아진다 (예: track_01은 20m 폭 트랙이라 카트가 3cm도 안 됨 — 거의 안 보여서
            // "차가 안 움직인다"로 보인 원인). 카트는 트랙 크기와 무관하게 눈에 보이는 고정 크기로 둔다.
            KartFitter.fit(entity, maxDimension: kartVisualLength)

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
