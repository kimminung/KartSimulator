#if os(visionOS)
import SwiftUI
import RealityKit
import ARKit
import simd

struct ImmersiveBoxView: View {
    @Environment(KartSelectionModel.self) private var selection
    @Environment(ImmersiveSessionModel.self) private var immersiveSession
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var rootEntity = Entity()
    @State private var kartSlot = Entity()
    @State private var inputCatcher = Entity()
    @State private var loadedKartID: String?
    @State private var loadedColorID: String?
    @State private var isLoading = false

    @State private var motion = KartMotionState()
    @State private var inputResolver = HandInputResolver()
    @State private var updateSubscription: Any?
    /// 디오라마(기본) / 1인칭(머리 방향 조향) / 3인칭(한손 핀치 좌우회전) — 결정 39.
    @State private var mode: ExperienceMode = .diorama

    @State private var track: TrackDefinition?
    @State private var trackPath: TrackPath?
    @State private var lapTracker: LapTracker?
    @State private var offTrackMonitor = OffTrackMonitor()
    @State private var wasAgainstWall = false
    @State private var trackDisplayScale: Float = 1
    @State private var trackWorldCenter: SIMD2<Float> = .zero

    // MARK: - 씬 루트 (Phase 2, 결정 44)
    // 트랙 타일·카트·트레일은 전부 `sceneRoot` 아래에 **트랙 좌표계(미터, 노면 y = 0) 실제 크기**로 둔다.
    // 모드에 따라 `sceneRoot`의 변환(`world = position + scale · R_y(yaw) · local`)만 바꾼다:
    // 디오라마 = 박스 맞춤 배율 + 180° 회전(결정 43) + 박스 바닥, 1인칭·3인칭 = 배율 1 + 매 프레임
    // 카트가 사용자 머리 아래(또는 앞)로 오도록 평행이동(월드는 돌지 않는다 — 멀미 요인 최소화).
    @State private var sceneRoot = Entity()
    @State private var boxFrame = Entity()
    @State private var boxFloor = Entity()
    @State private var hudEntity: Entity?
    @State private var loadedKartEntity: Entity?
    /// 현재 씬 루트의 Y축 회전. 디오라마는 `dioramaYaw`, 콕핏 모드는 모드에 들어온 순간 머리 방향으로 계산.
    @State private var sceneYaw: Float = .pi
    /// 콕핏 모드에 들어온 순간의 머리 위치(월드). 이후 카트는 매 프레임 이 점 기준으로 따라붙는다.
    @State private var cockpitAnchor: SIMD3<Float> = [0, 1.2, 0]
    private let cockpitTuning = CockpitTuning()
    /// 디오라마: 트랙 JSON의 출발 방향은 랩·체크포인트 판정 기준이라 건드리지 않고, 박스 안의 트랙 전체를
    /// 180° 돌려 사용자 쪽에서 볼 때 카트가 반대쪽을 보고 출발하게 한다(결정 43번).
    private let dioramaYaw: Float = .pi
    @State private var raceModel = RaceModel()
    @State private var tileLibrary = TrackTileLibrary()

    // 엔진음 + 효과음 (`Assets/sfx/ENGINE.md` 스펙대로, 디자인 결정 20-6).
    @State private var engineMachine = EngineSoundMachine()
    @State private var engineAudioPlayer: EngineAudioPlayer?
    @State private var sfxPlayer: SFXPlayer?

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
    /// 트랙 좌표(미터) 기준 이 거리 이상 움직였을 때만 새 선 조각을 추가한다(매 프레임 추가하면 세그먼트가 과도하게 늘어난다).
    private let trailMinSegmentLength: Float = 0.1
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

            boxFrame = BoxFrameBuilder.makeFrame(size: boxSize, thickness: 0.006, color: .white)
            rootEntity.addChild(boxFrame)

            let floor = ModelEntity(
                mesh: .generateBox(width: boxSize.x * 0.96, height: 0.01, depth: boxSize.z * 0.96),
                // 트랙 노면 색(`Design/style-guide.md` 1-1장, 디자인 결정 20-11).
                materials: [SimpleMaterial(color: .style(StylePalette.road), roughness: 0.6, isMetallic: false)]
            )
            floor.position.y = -boxSize.y / 2 + 0.005
            rootEntity.addChild(floor)
            boxFloor = floor

            // 씬 루트(트랙 좌표계 실제 크기). 변환은 `applyModeLayout()`이 모드별로 정한다.
            sceneRoot.name = "sceneRoot"
            content.add(sceneRoot)

            kartSlot.name = "kartSlot"
            sceneRoot.addChild(kartSlot)

            // 엔진음·효과음을 kartSlot에 붙인다(카트 모델 자체가 아니라 — 카트는 색상/모델이
            // 바뀔 때마다 통째로 교체되지만 kartSlot은 그대로라, 여기 붙이면 다시 로드할 필요가 없다).
            do {
                engineAudioPlayer = try EngineAudioPlayer(kart: kartSlot)
            } catch {
                print("엔진음 로드 실패: \(error)")
            }
            sfxPlayer = SFXPlayer(entity: kartSlot)

            // 디버그: 카트가 실제로 지나간 경로를 빨간 선으로 남긴다. 씬 루트(트랙 좌표계)에 쌓아 모드와 무관하게 따라온다.
            sceneRoot.addChild(trailRoot)

            // 핀치 제스처를 받으려면 InputTargetComponent + CollisionComponent가 있는 엔티티가
            // 필요하다(없으면 SpatialEventGesture가 아무것도 조준하지 못해 완전히 무반응이다).
            // 박스보다 살짝 넉넉하게 잡아 시선이 박스 언저리만 향해도 핀치가 잡히게 한다. 처음엔
            // `boxSize * 3`(약 2.1m 입방체)을 썼는데, 창(ContentView)의 "박스 닫기" 버튼 영역까지
            // 침범해서 그쪽 호버가 잘 안 잡히는 부작용이 있었다(결정 26번) — 1.4배로 줄였다.
            inputCatcher.position = boxPosition
            inputCatcher.components.set(CollisionComponent(shapes: [.generateBox(size: boxSize * 1.4)]))
            inputCatcher.components.set(InputTargetComponent())
            content.add(inputCatcher)

            content.add(rootEntity)
            loadTrack()
            if let track {
                await buildTrackTiles(definition: track, into: sceneRoot)
            }

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
                hudEntity = hudAttachment
            }

            updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                let desiredHeading = updateHeadDebugGizmo()
                tickMotion(deltaTime: Float(event.deltaTime), desiredHeading: desiredHeading)
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
            // "박스 닫기"를 창(ContentView)의 버튼이 아니라 이 패널에도 넣어 둔다. 창 버튼은
            // `inputCatcher`와 같은 공간을 공유해 호버가 불안정했는데(결정 26번), 박스 바로 위에
            // 떠 있는 이 패널은 겹치는 엔티티가 없어 바라보고 누르기 훨씬 쉽다.
            Attachment(id: "hud") {
                RaceHUDOverlay(hud: raceModel.hud, mode: mode, onModeChange: { mode = $0 }) {
                    Task {
                        await dismissImmersiveSpace()
                        immersiveSession.isOpen = false
                    }
                }
            }
        }
        .gesture(driveGesture)
        .onChange(of: mode) { _, _ in
            applyModeLayout()
        }
        .task {
            await runHUDUpdateLoop()
        }
    }

    // MARK: - 모드별 씬 배치 (Phase 2, 결정 44)

    /// 모드가 바뀌거나 트랙을 막 읽었을 때 한 번 호출. 박스 프레임·바닥 표시, 씬 루트 변환, 카트 크기,
    /// HUD 위치, 입력 캐처 범위를 모드에 맞춘다. 콕핏 모드의 매 프레임 따라붙기는 `tickMotion`이 한다.
    @MainActor
    private func applyModeLayout() {
        let isDiorama = mode == .diorama
        boxFrame.isEnabled = isDiorama
        boxFloor.isEnabled = isDiorama

        if isDiorama {
            sceneYaw = dioramaYaw
            sceneRoot.scale = SIMD3(repeating: trackDisplayScale)
            sceneRoot.orientation = simd_quatf(angle: sceneYaw, axis: [0, 1, 0])
            // 트랙 중심(노면 y = 0)이 박스 바닥 중앙에 오게.
            let boxFloorWorld = boxPosition + SIMD3(0, -boxSize.y / 2 + 0.011, 0)
            sceneRoot.position = ScenePlacement.rootPosition(
                placing: SIMD3(trackWorldCenter.x, 0, trackWorldCenter.y),
                at: boxFloorWorld, yaw: sceneYaw, scale: trackDisplayScale
            )
            hudEntity?.position = hudPosition
            inputCatcher.position = boxPosition
            inputCatcher.components.set(CollisionComponent(shapes: [.generateBox(size: boxSize * 1.4)]))
        } else {
            // 모드에 들어온 순간의 머리 위치·방향을 기준으로 잡는다(시뮬레이터처럼 못 읽으면 기본값).
            let head = currentHeadPose() ?? (position: SIMD3<Float>(0, 1.2, 0), yaw: Float(0))
            cockpitAnchor = head.position
            sceneYaw = ScenePlacement.sceneYaw(startHeading: track?.start.heading ?? 0, headYaw: head.yaw)
            sceneRoot.scale = SIMD3(repeating: 1)
            sceneRoot.orientation = simd_quatf(angle: sceneYaw, axis: [0, 1, 0])
            followKart()
            // HUD는 들어온 순간 머리 앞 1.2 m, 약간 아래에 고정(빌보드라 방향은 알아서 사용자를 본다).
            let hudForward = ScenePlacement.forward(heading: head.yaw)
            hudEntity?.position = head.position + hudForward * 1.2 + SIMD3(0, -0.15, 0)
            // 핀치는 `inputCatcher`를 봐야만 잡히므로(결정 26·33) 실제 크기 모드에서는 사용자 주변 전체를 덮는다.
            inputCatcher.position = head.position
            inputCatcher.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3(repeating: 40))]))
        }

        if let kart = loadedKartEntity {
            fitKart(kart)
        }
        print("DEBUG-LAYOUT mode=\(mode) sceneYaw=\(sceneYaw * 180 / .pi)도 scale=\(sceneRoot.scale.x) anchor=\(cockpitAnchor)")
    }

    /// 콕핏 모드: 카트의 트랙 좌표가 콕핏 목표점(머리 아래 / 앞)에 오도록 씬 루트를 평행이동한다.
    @MainActor
    private func followKart() {
        guard mode != .diorama else { return }
        let target = ScenePlacement.cockpitTarget(
            anchor: cockpitAnchor, mode: mode, kartHeading: motion.heading, sceneYaw: sceneYaw, tuning: cockpitTuning
        )
        sceneRoot.position = ScenePlacement.rootPosition(placing: motion.position, at: target, yaw: sceneYaw, scale: 1)
    }

    /// 카트 모델 크기: 디오라마는 박스 배율과 무관한 고정 시각 크기(`kartVisualLength`), 실제 크기 모드는 전장 1.5 m.
    @MainActor
    private func fitKart(_ entity: Entity) {
        let length = ScenePlacement.kartFitLength(
            mode: mode, sceneScale: sceneRoot.scale.x, dioramaVisualLength: kartVisualLength, tuning: cockpitTuning
        )
        KartFitter.fit(entity, maxDimension: length)
    }

    /// 머리(기기) 위치와 yaw(씬 좌표계, `KartMotionState`와 같은 heading 공식). 월드 트래킹이 없으면 nil.
    @MainActor
    private func currentHeadPose() -> (position: SIMD3<Float>, yaw: Float)? {
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return nil }
        let t = anchor.originFromAnchorTransform
        let position = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        let forward = -SIMD3<Float>(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        return (position, atan2(-forward.x, -forward.z))
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
            .onChanged { value in ingest(value, isEnding: false) }
            .onEnded { value in ingest(value, isEnding: true) }
    }

    private func ingest(_ value: EntityTargetValue<SpatialEventGesture.Value>, isEnding: Bool) {
        let events = value.gestureValue
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
            // `event.location3D`는 `inputCatcher`의 로컬 좌표계라 미터 단위가 아니다 — 실기기 로그로
            // 보면 수백 단위로 찍혀서, 미터 기준으로 잡아 둔 핀치 거리 임계값(40cm 등)이 전부 무의미해지고
            // 양손 거리가 늘 한쪽 극단에 고정돼 있었다(결정 33번). Apple 공식 샘플(Petite Asteroids)처럼
            // scene(월드, 미터) 좌표로 변환해서 써야 한다.
            let scenePosition = value.convert(event.location3D, from: .local, to: .scene)
            let position = SIMD3<Float>(Float(scenePosition.x), Float(scenePosition.y), Float(scenePosition.z))
            print("DEBUG-GESTURE \(hand == .left ? "LEFT" : "RIGHT") phase=\(event.phase) pinching=\(pinching) pos=\(position)")
            // `event.timestamp`는 SwiftUI 제스처 전용 시계라 `tickMotion`의 `now`(CACurrentMediaTime)와
            // 기준 시점이 다르다. 두 값을 그대로 비교하면 항상 "스테일"로 판정돼 `HandInputResolver`가
            // 영원히 .stopped만 반환한다(실기기에서 "차가 안 움직인다"의 진짜 원인, 결정 24번 참고).
            // 받는 즉시 같은 시계(CACurrentMediaTime)로 다시 찍어서 넘긴다.
            inputResolver.ingest(HandSample(chirality: hand, isPinching: pinching, position: position, timestamp: CACurrentMediaTime()))
        }
    }

    /// `Tracks/track_01.json`(앱 번들에 복사된 사본)을 읽어 월드→박스 배율을 계산한다.
    /// 타일 3D 배치는 `buildTrackTiles(definition:into:)`가 비동기로 따로 한다(디자인 결정 36-4).
    @MainActor
    private func loadTrack() {
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

            let startPoint = path.points[definition.start.pathIndex]
            motion = KartMotionState(
                speed: 0,
                heading: definition.start.heading,
                position: SIMD3(startPoint.x, 0, startPoint.y)
            )
            raceModel.start(totalLaps: definition.laps)
            applyModeLayout()
            startCountdown()
        } catch {
            print("트랙 로드 실패: \(error)")
        }
    }

    /// `Assets/sfx/ENGINE.md` 3-4장: 카운트다운 시작(`countdownTick` 3회) → GO. 시동(`engineIgnition`)은
    /// 카운트다운과 동시에 시작해 2.2초 뒤 공회전으로 넘어간다 — 별도 타이밍이라 병렬로 돈다.
    private func startCountdown() {
        engineAudioPlayer?.run(engineMachine.countdownStarted())
        Task {
            for _ in 0..<3 {
                sfxPlayer?.play(.countdownTick)
                try? await Task.sleep(for: .seconds(1))
            }
            sfxPlayer?.play(.go)
        }
    }

    /// 트랙 그리드 전체를 실제 타일 3D 모델(`tile_straight`/`tile_curve`/`tile_start`/`tile_grass`)로
    /// 깐다 — 디자인 결정 36-4로 타일 에셋이 도착해서, 점열 placeholder(이전 구현)를 대체한다.
    /// `tiles`에 없는 칸은 전부 잔디로 채운다.
    @MainActor
    private func buildTrackTiles(definition: TrackDefinition, into parent: Entity) async {
        guard !definition.tiles.isEmpty else { return }
        // 씬 루트는 트랙 좌표계(노면 y = 0)다. 박스 바닥 높이·배율은 `applyModeLayout()`이 씬 루트 변환으로 준다.
        let floorY: Float = 0
        var occupied = Set<Int>()

        func cellKey(_ col: Int, _ row: Int) -> Int { row * definition.grid.cols + col }

        // 잔디는 실제 트랙 타일이 차지하는 칸의 바운딩 사각형만 채운다 — `grid.cols`×`grid.rows`
        // 전체(생성 시 여백 포함)를 채우면 `trackDisplayScale`(트랙 경로 바운딩 박스 기준)보다
        // 커져서 박스 밖으로 넘친다. `gen_track.py`의 타일 중심 공식과 맞춰 보면 타일 바운딩 사각형이
        // 정확히 `path`의 바운딩 박스와 일치한다(둘 다 같은 타일 중심들에서 나왔으니까).
        let cols = definition.tiles.map(\.col)
        let rows = definition.tiles.map(\.row)
        let colRange = cols.min()!...cols.max()!
        let rowRange = rows.min()!...rows.max()!

        for tile in definition.tiles {
            occupied.insert(cellKey(tile.col, tile.row))
            // `rot`은 gen_track.py의 시계방향(컴퍼스) 각도인데, 우리 쪽 Y축 회전(simd_quatf)은
            // 반시계 방향이 양수라 부호를 뒤집는다 — 타일끼리 이음새가 안 맞으면 여기부터 의심한다.
            await placeTile(
                type: tile.type,
                col: tile.col,
                row: tile.row,
                rotationDegrees: -Float(tile.rot),
                tileSize: definition.tileSize,
                floorY: floorY,
                into: parent
            )
        }

        for row in rowRange {
            for col in colRange where !occupied.contains(cellKey(col, row)) {
                await placeTile(
                    type: "grass",
                    col: col,
                    row: row,
                    rotationDegrees: 0,
                    tileSize: definition.tileSize,
                    floorY: floorY,
                    into: parent
                )
            }
        }
    }

    @MainActor
    private func placeTile(
        type: String,
        col: Int,
        row: Int,
        rotationDegrees: Float,
        tileSize: Float,
        floorY: Float,
        into parent: Entity
    ) async {
        guard let entity = await tileLibrary.makeTile(type: type) else { return }
        // 트랙 좌표계 그대로(실제 크기, 미터). gen_track.py의 타일 중심 공식과 동일.
        let center = SIMD2(Float(col) * tileSize + tileSize / 2, -(Float(row) * tileSize + tileSize / 2))
        entity.position = SIMD3(center.x, floorY, center.y)
        entity.orientation = simd_quatf(angle: rotationDegrees * .pi / 180, axis: [0, 1, 0])
        parent.addChild(entity)
    }

    /// 디버그 전용: 트랙 좌표(XZ, 미터) 두 점을 빨간 막대 하나로 이어 붙인다(경로 누적용). 씬 루트 아래라
    /// 디오라마에서는 배율만큼 작아지고(약 2 mm), 실제 크기 모드에서는 6 cm 폭으로 노면에 깔린다.
    @MainActor
    private func addTrailSegment(from a: SIMD2<Float>, to b: SIMD2<Float>) {
        let floorY: Float = 0.03
        let start = SIMD3<Float>(a.x, floorY, a.y)
        let end = SIMD3<Float>(b.x, floorY, b.y)
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0001 else { return }

        let material = UnlitMaterial(color: .red)
        let segment = ModelEntity(
            mesh: .generateBox(size: SIMD3(0.06, 0.06, length)),
            materials: [material]
        )
        segment.position = (start + end) / 2
        segment.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(delta))
        trailRoot.addChild(segment)
    }

    /// 헤드 앵커 위치에 구슬을, 기기 정면 방향으로 막대를 띄운다(디버그 시각화, 결정 21번).
    /// 1인칭 모드에서는 여기서 구한 정면 방향이 그대로 조향 입력(`desiredHeading`)이 된다 —
    /// "아이트래킹"이라고 불러왔지만 실제로는 머리(기기) 방향이다(결정 39 기술 노트). 여기서 돌려주는 값은
    /// **씬(월드) 좌표계** heading이다 — 트랙 좌표계로 쓰려면 `tickMotion`에서 `sceneYaw`를 빼야 한다(결정 43·44번).
    @MainActor
    @discardableResult
    private func updateHeadDebugGizmo() -> Float? {
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return nil }
        let transform = anchor.originFromAnchorTransform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        // 디바이스 로컬 -Z가 정면이다(RealityKit/ARKit 공통 관례).
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let direction = simd_normalize(forward)

        headMarker.position = position
        gazeRay.position = position + direction * (gazeRayLength / 2)
        gazeRay.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)

        return atan2(-direction.x, -direction.z)
    }

    @MainActor
    private func tickMotion(deltaTime: Float, desiredHeading: Float?) {
        guard deltaTime > 0, let track, let trackPath, let lapTracker else { return }

        // `ingest()`에서 찍는 시계(CACurrentMediaTime)와 반드시 같은 기준이어야 한다. 섞어 쓰면
        // HandInputResolver의 스테일 판정이 항상 틀어진다(결정 24번).
        let now = CACurrentMediaTime()
        let (drive, leftStatus, rightStatus) = inputResolver.resolve(now: now, mode: mode)
        let tuning = MotionTuning().applying(track.tuning)
        // 머리 방향은 씬(월드) 좌표계 기준이라, 씬 루트 회전 `sceneYaw`를 빼서 트랙 좌표계 heading으로 되돌린다.
        let trackSpaceDesiredHeading = desiredHeading.map { $0 - sceneYaw }
        motion = motion.advancing(drive: drive, desiredHeading: mode == .firstPerson ? trackSpaceDesiredHeading : nil, tuning: tuning, deltaTime: deltaTime)

        let positionXZ = SIMD2(motion.position.x, motion.position.z)
        let (pathIndex, distanceFromCenterline, projectedOnCenterline) = trackPath.closestSegment(to: positionXZ)
        let previousProgress = lapTracker.progress
        lapTracker.update(pathIndex: pathIndex)
        let newProgress = lapTracker.progress

        // 효과음: 완주 > 랩 완료 > 체크포인트 순으로 우선순위를 둔다(동시에 일어나면 완주가 제일 중요하다).
        if !previousProgress.isFinished && newProgress.isFinished {
            sfxPlayer?.play(.finish)
            engineAudioPlayer?.run(engineMachine.finished())
        } else if newProgress.currentLap != previousProgress.currentLap {
            sfxPlayer?.play(.lapComplete)
        } else if newProgress.checkpointsPassedThisLap > previousProgress.checkpointsPassedThisLap {
            sfxPlayer?.play(.checkpoint)
        }

        // 벽 콜리전: 타일 가장자리(중심선에서 tileSize/2)를 벽으로 보고 그 안쪽으로 밀어낸다 — 타일
        // 메시로 레이캐스트하는 대신, 이미 매 프레임 계산하는 중심선 거리를 그대로 재사용한 단순 모델.
        // 실제로는 커브 타일 안쪽 모서리엔 벽이 없다(이슈 #9)지만, 좌우를 구분 안 하는 이 모델은
        // 양쪽을 다 막는다 — 실기기에서 커브 안쪽이 막혀 어색하면 다시 손봐야 한다.
        let wallDistance = track.tileSize / 2
        if distanceFromCenterline > wallDistance {
            let outward = positionXZ - projectedOnCenterline
            let outwardLength = simd_length(outward)
            let direction = outwardLength > 0.0001 ? outward / outwardLength : SIMD2<Float>(1, 0)
            let clamped = projectedOnCenterline + direction * wallDistance
            motion.position.x = clamped.x
            motion.position.z = clamped.y
            if !wasAgainstWall {
                sfxPlayer?.play(.wallBump)
            }
            wasAgainstWall = true
        } else {
            wasAgainstWall = false
        }

        let isOffTrack = distanceFromCenterline > (track.width / 2 + 0.5)
        offTrackMonitor.update(isOffTrack: isOffTrack, deltaTime: TimeInterval(deltaTime), threshold: tuning.offTrackRespawn)

        latestDrive = drive
        latestLeftStatus = leftStatus
        latestRightStatus = rightStatus
        latestSpeed = motion.speed
        latestLapProgress = newProgress
        latestCheckpointCount = track.checkpoints.count
        latestIsOffTrack = isOffTrack

        // 엔진음: DriveState → 페달 크기(방향 무관)·회전 중 유지 여부로 바꿔 상태 기계에 먹인다
        // (ENGINE.md는 forwardHalf/forwardFull 2단계 기준이었는데, 지금은 연속 페달이라 크기를 그대로 쓴다).
        let pedalMagnitude: Double
        let isHolding: Bool
        switch drive {
        case .pedal(let value):
            pedalMagnitude = Double(abs(value))
            isHolding = false
        case .turnLeft, .turnRight:
            pedalMagnitude = 0
            isHolding = true
        case .stopped, .waiting:
            pedalMagnitude = 0
            isHolding = false
        case .headSteered(let accelerating):
            pedalMagnitude = accelerating ? 1.0 : 0.0
            isHolding = false
        }
        let engineCommands = engineMachine.update(
            dt: Double(deltaTime),
            pedal: pedalMagnitude,
            isHolding: isHolding,
            speed: Double(motion.speed),
            maxSpeed: Double(tuning.maxSpeed)
        )
        engineAudioPlayer?.run(engineCommands)

        if offTrackMonitor.shouldRespawn {
            let startPoint = trackPath.points[track.start.pathIndex]
            motion = KartMotionState(
                speed: tuning.respawnSpeed,
                heading: track.start.heading,
                position: SIMD3(startPoint.x, 0, startPoint.y)
            )
            lapTracker.resetPosition(pathIndex: track.start.pathIndex)
            offTrackMonitor.acknowledgeRespawn()
            sfxPlayer?.play(.respawn)
            engineAudioPlayer?.run(engineMachine.respawned())
        }

        // 카트는 씬 루트(트랙 좌표계) 안에서 트랙 좌표 그대로 움직인다. 표시 배율·회전·콕핏 따라붙기는 씬 루트 몫.
        let kartTrackPosition = SIMD2(motion.position.x, motion.position.z)
        kartSlot.position = SIMD3(kartTrackPosition.x, 0, kartTrackPosition.y)
        kartSlot.orientation = simd_quatf(angle: motion.heading, axis: [0, 1, 0])
        followKart()

        // 디버그: 실제로 이동한 거리를 빨간 선으로 쌓고, 콘솔에도 주기적으로 남긴다.
        if let last = lastTrailDisplayPoint {
            if simd_distance(last, kartTrackPosition) >= trailMinSegmentLength {
                addTrailSegment(from: last, to: kartTrackPosition)
                lastTrailDisplayPoint = kartTrackPosition
            }
        } else {
            lastTrailDisplayPoint = kartTrackPosition
        }

        totalDistanceTraveled += motion.speed * deltaTime
        motionLogAccumulator += deltaTime
        if motionLogAccumulator >= motionLogInterval {
            motionLogAccumulator = 0
            print("DEBUG-MOTION drive=\(drive) speed=\(motion.speed)m/s pos=\(motion.position) totalDistance=\(totalDistanceTraveled)m")
        }
    }

    /// 카트 계층에서 이름에 "front"가 들어간 자식 엔티티(Reality Composer Pro에서 차량 앞을
    /// 표시해 둔 마커)를 찾아, 그 방향을 주행 수학의 정면 축인 로컬 **-Z**로 보내는 Y축 보정 각도를
    /// 계산한다(`KartForwardCorrection`, 결정 29·42번). 마커가 없으면 `fallbackDegrees`를 그대로 쓴다.
    ///
    /// 결정 32번에서 목표를 +Z로 뒤집었던 적이 있는데, 그건 손 좌표 변환 버그(결정 33번)로 카트가
    /// 실제로 후진하던 것을 모델이 뒤집힌 것으로 오인한 수정이었다. 실기기에서 "뒷부분부터 전진"으로
    /// 다시 보고되어 -Z로 되돌렸다(결정 42번). 공식은 `KartCoreTests`가 세 축으로 고정한다.
    private func frontCorrectionAngle(for entity: Entity, fallbackDegrees: Float) -> Float {
        guard let front = findDescendant(in: entity, nameContains: "front") else {
            print("DEBUG-FRONT 'front' 이름의 자식을 못 찾음 — fallback \(fallbackDegrees)도 사용")
            return fallbackDegrees * .pi / 180
        }
        let nose = front.position(relativeTo: entity)
        guard let angle = KartForwardCorrection.angle(noseX: nose.x, noseZ: nose.z) else {
            print("DEBUG-FRONT '\(front.name)' 위치가 원점과 거의 같아 방향을 못 구함 — fallback \(fallbackDegrees)도 사용")
            return fallbackDegrees * .pi / 180
        }
        let after = KartForwardCorrection.rotatedXZ(noseX: nose.x, noseZ: nose.z, by: angle)
        print("DEBUG-FRONT '\(front.name)' 위치=\(nose) → 보정 \(angle * 180 / .pi)도, 보정 후 nose XZ=\(after) (목표 (0, -1))")
        return angle
    }

    private func findDescendant(in entity: Entity, nameContains substring: String) -> Entity? {
        if entity.name.lowercased().contains(substring) {
            return entity
        }
        for child in entity.children {
            if let found = findDescendant(in: child, nameContains: substring) {
                return found
            }
        }
        return nil
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
            // 주행 로직은 `kartSlot.orientation`을 "모델의 정면은 로컬 -Z"라는 전제로 돌린다(결정 27번).
            // Reality Composer Pro에서 내보낸 계층에는 차량 앞을 가리키는 "front"라는 이름의 자식
            // 엔티티가 들어 있어, 그 위치를 읽어서 보정 각도를 모델마다 자동으로 계산한다(결정 29·42번).
            // 못 찾으면 `KartModel.modelForwardCorrectionDegrees`(이 로스터는 +Z가 정면이라 180도)로 돌아간다.
            entity.orientation = simd_quatf(
                angle: frontCorrectionAngle(for: entity, fallbackDegrees: kart.modelForwardCorrectionDegrees),
                axis: [0, 1, 0]
            )
            // 디오라마: 트랙 배율(trackDisplayScale)을 카트에도 그대로 쓰면 트랙이 넓을수록 카트가 같이
            // 작아진다(track_01은 20m 폭이라 3cm도 안 됨). 트랙 크기와 무관하게 고정 시각 크기(0.12 m)로 두되,
            // 씬 루트가 배율을 갖고 있으니 트랙 단위로는 그만큼 키워서 넣는다. 실제 크기 모드는 전장 1.5 m(결정 44).
            fitKart(entity)

            kartSlot.children.removeAll()
            kartSlot.addChild(entity)
            loadedKartEntity = entity

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
    let mode: ExperienceMode
    let onModeChange: (ExperienceMode) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ModeSwitchView(mode: mode, onModeChange: onModeChange)
            VStack(spacing: 4) {
                Text("LAP \(hud.lap) / \(hud.totalLaps)")
                    .font(.headline)
                    .foregroundStyle(Color.style(StylePalette.uiInk))
                Text(String(format: "%.1f s", hud.lapTime))
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(Color.style(StylePalette.uiInk))
                Text(String(format: "%.0f km/h", hud.speedKmh))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.style(StylePalette.uiInk))
                if hud.respawning {
                    Text("트랙 이탈")
                        .font(.caption.bold())
                        .foregroundStyle(Color.style(StylePalette.uiWarn))
                }
            }
            PinchStatusView(drive: hud.drive, left: hud.left, right: hud.right)
            Button("박스 닫기", action: onClose)
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 모드 전환 버튼 3개 — 평범한 SwiftUI `Button`이라 시스템이 표준 시선+핀치 선택을 그대로 처리한다
/// ("아이트래킹으로 전환"의 실제 구현, 결정 39 기술 노트. visionOS는 서드파티 앱에 원시 눈동자
/// 방향을 주지 않는다 — 버튼을 보면서 핀치하는 일반적인 선택 방식일 뿐이다).
private struct ModeSwitchView: View {
    let mode: ExperienceMode
    let onModeChange: (ExperienceMode) -> Void

    private let labels: [ExperienceMode: String] = [
        .diorama: "디오라마",
        .firstPerson: "1인칭",
        .thirdPerson: "3인칭",
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ExperienceMode.allCases, id: \.self) { candidate in
                modeButton(for: candidate)
            }
        }
    }

    @ViewBuilder
    private func modeButton(for candidate: ExperienceMode) -> some View {
        let title: String = labels[candidate] ?? candidate.rawValue
        if candidate == mode {
            Button(title) { onModeChange(candidate) }
                .buttonStyle(.borderedProminent)
                .font(.caption)
        } else {
            Button(title) { onModeChange(candidate) }
                .buttonStyle(.bordered)
                .font(.caption)
        }
    }
}

/// 핀치 상태 6상태 + 페달 게이지 (디자인 PRD 7장, 결정 36-1). 왼손/오른손 핀치 여부, 가운데
/// 동작 아이콘, 전진(`ui-cyan` ↑)·후진(`ui-magenta` ↓) 세기를 색+모양+방향 세 가지로 함께 보여준다.
/// 아이콘은 디자인 SVG 세트(`Design/icons/`) 대신 SF Symbols로 자리만 잡아 둔 상태.
private struct PinchStatusView: View {
    let drive: DriveState
    let left: HandStatus
    let right: HandStatus

    private var pedalValue: Float {
        if case .pedal(let value) = drive { return value }
        return 0
    }

    /// `waiting`(거리 계산 전 과도기)도 `pedal(0)`과 같은 중립 행으로 취급해 게이지를 그대로 보여준다
    /// (디자인 PRD 7장 표에서 두 상태를 한 줄로 묶어 둠).
    private var showsGauge: Bool {
        switch drive {
        case .pedal, .waiting: return true
        default: return false
        }
    }

    private var gaugeLabel: String {
        if pedalValue > 0.02 { return "전진 \(Int((pedalValue * 100).rounded()))%" }
        if pedalValue < -0.02 { return "후진 \(Int((-pedalValue * 100).rounded()))%" }
        return "중립"
    }

    var body: some View {
        HStack(spacing: 10) {
            handDot(pinching: left.pinching)
            centerIcon
            if showsGauge {
                VStack(spacing: 2) {
                    PedalGaugeBar(value: pedalValue)
                    Text(gaugeLabel)
                        .font(.caption2)
                        .foregroundStyle(Color.style(StylePalette.uiInk).opacity(0.8))
                }
            }
            handDot(pinching: right.pinching)
        }
    }

    @ViewBuilder
    private var centerIcon: some View {
        switch drive {
        case .stopped:
            Image(systemName: "stop.fill")
                .foregroundStyle(Color.style(StylePalette.uiInk).opacity(0.4))
        case .turnLeft:
            Image(systemName: "arrowshape.turn.up.left.fill")
                .foregroundStyle(Color.style(StylePalette.uiInk))
        case .turnRight:
            Image(systemName: "arrowshape.turn.up.right.fill")
                .foregroundStyle(Color.style(StylePalette.uiInk))
        case .waiting:
            EmptyView()
        case .pedal(let value) where value > 0.02:
            Image(systemName: "arrow.up")
                .foregroundStyle(Color.style(StylePalette.uiCyan))
        case .pedal(let value) where value < -0.02:
            Image(systemName: "arrow.down")
                .foregroundStyle(Color.style(StylePalette.uiMagenta))
        case .pedal:
            EmptyView()
        case .headSteered(let accelerating):
            Image(systemName: accelerating ? "arrow.up" : "stop.fill")
                .foregroundStyle(accelerating ? Color.style(StylePalette.uiCyan) : Color.style(StylePalette.uiInk).opacity(0.4))
        }
    }

    private func handDot(pinching: Bool) -> some View {
        Circle()
            .fill(pinching ? Color.style(StylePalette.uiCyan) : Color.style(StylePalette.uiInk).opacity(0.4))
            .frame(width: 10, height: 10)
    }
}

/// 세로 페달 게이지: 가운데 눈금이 중립, 위쪽은 전진(`ui-cyan`), 아래쪽은 후진(`ui-magenta`)
/// 세기를 `abs(pedal)`(0~1)만큼 채운다 (디자인 PRD 7장 "페달 게이지").
private struct PedalGaugeBar: View {
    let value: Float

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let half = geo.size.height / 2
            let fillHeight = CGFloat(min(max(abs(value), 0), 1)) * half
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.style(StylePalette.uiRim))
                Rectangle()
                    .fill(Color.style(StylePalette.uiInk).opacity(0.6))
                    .frame(width: width, height: 1)
                    .position(x: width / 2, y: half)
                if fillHeight > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.style(value >= 0 ? StylePalette.uiCyan : StylePalette.uiMagenta))
                        .frame(width: width, height: fillHeight)
                        .position(x: width / 2, y: value >= 0 ? half - fillHeight / 2 : half + fillHeight / 2)
                }
            }
        }
        .frame(width: 10, height: 42)
    }
}
#endif
