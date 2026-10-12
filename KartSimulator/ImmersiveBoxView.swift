#if os(visionOS)
import SwiftUI
import RealityKit
import ARKit
import simd

struct ImmersiveBoxView: View {
    @Environment(KartSelectionModel.self) private var selection
    @Environment(ImmersiveSessionModel.self) private var immersiveSession
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var rootEntity = Entity()
    @State private var kartSlot = Entity()
    @State private var inputCatcher = Entity()
    @State private var loadedKartID: String?
    @State private var loadedColorID: String?
    @State private var isLoading = false

    /// 레일 주행 상태(결정 58): 중심선 호 길이·가로 오프셋·상대 yaw·속도. 월드 자세는 `latestPose`.
    @State private var rail = RailMotionState()
    @State private var trackSpline: TrackSpline?
    @State private var latestPose = KartPose(position: .zero, forward: SIMD3(0, 0, -1), up: SIMD3(0, 1, 0), heading: 0)
    @State private var inputResolver = HandInputResolver()
    @State private var updateSubscription: Any?
    /// 디오라마(기본) / 3인칭(추적 카메라) — 결정 39·47·49. 두 모드의 손 조작은 같다.
    @State private var mode: ExperienceMode = .diorama

    @State private var track: TrackDefinition?
    @State private var trackPath: TrackPath?
    /// 지금 박스에 지어진 트랙 id. 메뉴 창에서 다른 트랙을 고르면(Issue #43) `update:`가 차이를 보고 `reloadTrack()`을 부른다.
    @State private var loadedTrackID: String?
    @State private var isReloadingTrack = false
    /// 타일만 모아 두는 루트(씬 루트 아래). 트랙을 바꿀 때 이 아래만 비우면 카트·트레일은 그대로 남는다.
    @State private var trackTilesRoot = Entity()
    @State private var lapTracker: LapTracker?
    @State private var trackDisplayScale: Float = 1
    @State private var trackWorldCenter: SIMD2<Float> = .zero

    // MARK: - 씬 루트 (Phase 2, 결정 44)
    // 트랙 타일·카트·트레일은 전부 `sceneRoot` 아래에 **트랙 좌표계(미터, 노면 y = 0) 실제 크기**로 둔다.
    // 모드에 따라 `sceneRoot`의 변환(`world = position + scale · R_y(yaw) · local`)만 바꾼다:
    // 디오라마 = 박스 맞춤 배율 + 180° 회전(결정 43) + 박스 바닥, 3인칭 = 배율 1 + 매 프레임 카트가 기준 방향
    // 2.5 m 앞으로 오도록 평행이동 + 카트 뒤에서 앞을 보도록 평활 회전(결정 44~47·49).
    @State private var sceneRoot = Entity()
    @State private var boxFrame = Entity()
    @State private var boxFloor = Entity()
    @State private var hudEntity: Entity?
    @State private var loadedKartEntity: Entity?
    /// 카트 움직이는 부품(핸들·차체·바퀴) 리그(Issue #26, 결정 51). 카트를 로드할 때마다 새로 만든다.
    @State private var kartRig: KartRig?
    /// 월드 좌표에 그대로 두는 것들(미니맵)의 부모. `rootEntity`는 박스 위치로 옮겨져 있어 기준이 다르다.
    @State private var worldAnchor = Entity()
    /// M4 미니맵(결정 48). 트랙을 읽은 뒤 비동기로 만들어진다.
    @State private var minimap: Minimap?
    /// 디오라마에서는 박스 앞오른쪽 모서리 위에 작게(지름 0.16 m), 콕핏에서는 HUD 옆에 원래 크기(0.24 m).
    private let minimapTableDiameter: Float = 0.24
    private let minimapDioramaDiameter: Float = 0.16
    /// 3인칭 미니맵 자리: HUD(머리 앞 1.2 m)보다 **더 오른쪽 아래**(실기기 피드백, 결정 53 — 0.45/0.45는 트랙 시야를 가렸다).
    private let thirdPersonMinimapRight: Float = 0.65
    private let thirdPersonMinimapDown: Float = 0.8
    @State private var latestMapPosition: SIMD2<Float> = .zero
    @State private var latestHeading: Float = 0
    /// 현재 씬 루트의 Y축 회전. 디오라마는 `dioramaYaw`, 콕핏 모드는 모드에 들어온 순간 머리 방향으로 계산.
    @State private var sceneYaw: Float = .pi
    /// 콕핏 모드에 들어온 순간의 머리 위치(월드). 이후 카트는 매 프레임 이 점 기준으로 따라붙는다.
    @State private var cockpitAnchor: SIMD3<Float> = [0, 1.2, 0]
    /// 3인칭 카메라 기준 방향(모드 진입 순간 머리 yaw, ±60°를 2초 넘게 벗어나면 리센터 — Issue #25, 결정 49).
    @State private var chaseReference = ChaseCameraReference(forwardYaw: 0)
    /// 3인칭 HUD·미니맵이 따라가는 평활 머리 yaw와 속도(1/s) — 결정 53.
    @State private var hudFollowYaw: Float = 0
    private let hudFollowRate: Float = 4
    /// 종료 안전망: 3인칭에서 정지 + 양손 해제가 이만큼 이어지면 메뉴 창을 다시 연다(결정 53 추가).
    @State private var stoppedHandsFreeSeconds: Float = 0
    private let menuWindowReopenAfter: Float = 4
    private let cockpitTuning = CockpitTuning()
    /// 디오라마: 트랙 JSON의 출발 방향은 랩·체크포인트 판정 기준이라 건드리지 않고, 박스 안의 트랙 전체를
    /// 180° 돌려 사용자 쪽에서 볼 때 카트가 반대쪽을 보고 출발하게 한다(결정 43번).
    private let dioramaYaw: Float = .pi
    @State private var raceModel = RaceModel()
    @State private var tileLibrary = TrackTileLibrary()
    // MARK: - 레이스 흐름 (M5, 결정 56): 카운트다운 잠금 → 주행 → 완주 결과 → 다시 하기
    /// 카운트다운 중·완주 뒤에는 손 입력을 무시한다(핀치해도 출발 못 하고, 완주 뒤엔 관성으로 선다).
    @State private var raceLocked = true
    /// 일시정지(Issue #44): 입력 잠금에 더해 주행 적분까지 멈춘다(카트가 그 자리에 선 채로 있음). 재개는 3·2·1 카운트다운 재사용.
    @State private var isPaused = false
    /// GO 직후 0.6초 동안 HUD에 "GO" 표시.
    @State private var showsGoFlash = false
    @State private var countdownTask: Task<Void, Never>?
    /// 완주 결과(총 시간·랩·베스트·신기록). HUD 결과 패널이 읽는다.
    @State private var raceResult: RaceResult?
    @State private var hudLoopLastTick: TimeInterval = CACurrentMediaTime()

    // 엔진음 + 효과음 (`Assets/sfx/ENGINE.md` 스펙대로, 디자인 결정 20-6).
    @State private var engineMachine = EngineSoundMachine()
    @State private var engineAudioPlayer: EngineAudioPlayer?
    @State private var sfxPlayer: SFXPlayer?
    // 배경음 3곡(디자인 결정 55, `Assets/bgm/README.md`): 머리 고정 앰비언트라 RealityKit 밖에서 `AVAudioPlayer`로 튼다.
    @State private var bgmPlayer = BGMPlayer()

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
    /// 디버그 시각물(헤드 구슬·시선 막대·주행 트레일) 표시 여부. 시연 영상에 초록 막대가 보여(Issue #31) 기본은 끔.
    /// 머리 yaw 계산·DEBUG 로그는 그대로 돈다 — 3인칭 리센터가 머리 yaw를 쓴다.
    private let showsDebugVisuals = false
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
    /// 박스 중심. Issue #27(결정 51): 메뉴 창이 박스를 가리지 않도록 박스를 창 **아래·앞**에 둔다 — 창은 프로그램으로
    /// 옮길 수 없어(visionOS는 첫 창 배치를 시스템이 정함) 박스 쪽을 낮췄다(윗면 1.05 m, 전에는 1.25 m).
    private let boxPosition: SIMD3<Float> = [0, 0.85, -0.9]
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
            trackTilesRoot.name = "trackTiles"
            sceneRoot.addChild(trackTilesRoot)

            // 엔진음·효과음을 kartSlot에 붙인다(카트 모델 자체가 아니라 — 카트는 색상/모델이
            // 바뀔 때마다 통째로 교체되지만 kartSlot은 그대로라, 여기 붙이면 다시 로드할 필요가 없다).
            do {
                engineAudioPlayer = try EngineAudioPlayer(kart: kartSlot)
            } catch {
                print("엔진음 로드 실패: \(error)")
            }
            sfxPlayer = SFXPlayer(entity: kartSlot)

            // 디버그: 카트가 실제로 지나간 경로를 빨간 선으로 남긴다. 씬 루트(트랙 좌표계)에 쌓아 모드와 무관하게 따라온다.
            trailRoot.isEnabled = showsDebugVisuals
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
            content.add(worldAnchor)
            loadTrack()
            await buildTrackScenery()

            // 디버그: 헤드 위치 구슬 + 시선 방향 막대. world 좌표계에 바로 두므로 rootEntity가 아니라
            // content에 직접 추가한다 (rootEntity는 박스 위치로 옮겨져 있어 기준이 다르다).
            let headMaterial = UnlitMaterial(color: .yellow)
            let headModel = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [headMaterial])
            headMarker.addChild(headModel)
            headMarker.isEnabled = showsDebugVisuals
            content.add(headMarker)

            let rayMaterial = UnlitMaterial(color: .green)
            let rayModel = ModelEntity(
                mesh: .generateBox(size: SIMD3(0.004, 0.004, gazeRayLength)),
                materials: [rayMaterial]
            )
            gazeRay.addChild(rayModel)
            gazeRay.isEnabled = showsDebugVisuals
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
                let headYaw = updateHeadDebugGizmo()
                tickMotion(deltaTime: Float(event.deltaTime), headYaw: headYaw)
            }
        } update: { _, _ in
            if !isReloadingTrack, let loadedTrackID, loadedTrackID != selection.selectedTrackID {
                isReloadingTrack = true
                Task {
                    await reloadTrack()
                    isReloadingTrack = false
                }
            }
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
                RaceHUDOverlay(hud: raceModel.hud, mode: mode, showsGoFlash: showsGoFlash, result: raceResult, onModeChange: { mode = $0 }, onRestart: { restartRace() }, onPause: { pauseRace() }, onResume: { resumeRace() }, onTrackSelect: {
                    // 트랙 카드는 메뉴 창에 있다. 3인칭에서 숨긴 창을 정면에 다시 열면 고르는 즉시 박스가 새 트랙으로 바뀐다(`reloadTrack`).
                    if immersiveSession.menuWindowHidden { openWindow(id: AppScene.menuWindowID); immersiveSession.menuWindowHidden = false }
                }) {
                    Task {
                        bgmPlayer.stop(fadeOut: 0.5) // 앱·박스 종료는 0.5초 페이드(배경음 규칙 2)
                        // 3인칭에서 숨긴 메뉴 창을 먼저 사용자 정면에 다시 연다(Issue #27). 창이 하나도 없으면 공간을 닫는 순간 앱이 사라진다.
                        if immersiveSession.menuWindowHidden { openWindow(id: AppScene.menuWindowID); immersiveSession.menuWindowHidden = false }
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
        .onDisappear {
            bgmPlayer.stop(fadeOut: 0.5)
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
        // 메뉴 창(Issue #27): 3인칭(실제 크기 트랙)에서는 창을 치우고, 디오라마로 돌아오면 다시 연다. 종료는 HUD "박스 닫기".
        if isDiorama {
            if immersiveSession.menuWindowHidden { openWindow(id: AppScene.menuWindowID); immersiveSession.menuWindowHidden = false }
        } else if !immersiveSession.menuWindowHidden {
            dismissWindow(id: AppScene.menuWindowID); immersiveSession.menuWindowHidden = true
        }

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
            // 기준 방향 = 진입 순간 머리 yaw. 들어오자마자 카트 뒤에서 앞을 보도록 씬 yaw를 바로 맞춘다.
            chaseReference = ChaseCameraReference(forwardYaw: head.yaw)
            hudFollowYaw = head.yaw
            sceneYaw = ScenePlacement.chaseSceneYaw(kartHeading: rail.heading, referenceYaw: head.yaw)
            sceneRoot.scale = SIMD3(repeating: 1)
            sceneRoot.orientation = simd_quatf(angle: sceneYaw, axis: [0, 1, 0])
            followKart(headYaw: head.yaw, deltaTime: 0)
            // HUD는 들어온 순간 머리 앞 1.2 m, 약간 아래에 고정(빌보드라 방향은 알아서 사용자를 본다).
            let hudForward = ScenePlacement.forward(heading: head.yaw)
            hudEntity?.position = head.position + hudForward * 1.2 + SIMD3(0, -0.15, 0)
            // 핀치는 `inputCatcher`를 봐야만 잡히므로(결정 26·33) 실제 크기 모드에서는 넓게 덮되, **머리를 콜라이더 안에
            // 넣지 않는다**(결정 53 추가): 머리가 40 m 상자 안에 있으면 시선 레이가 상자를 거리 0에서 맞춰 HUD 버튼이
            // 호버되지 않았다(실기기: 디오라마·3인칭·박스 닫기 버튼 먹통). 눈높이 1.1 m 아래의 바닥 슬래브(트랙·카트를
            // 보는 시선)와 기준 방향 15 m 앞의 벽(지평선 쪽 시선) 두 조각으로 나눠 HUD(눈앞 1.2 m)는 빈 공간에 둔다.
            inputCatcher.position = head.position
            inputCatcher.orientation = simd_quatf(angle: head.yaw, axis: [0, 1, 0])
            inputCatcher.components.set(CollisionComponent(shapes: Self.thirdPersonCatcherShapes()))
        }

        if let kart = loadedKartEntity {
            fitKart(kart)
        }
        layoutMinimap()
        print("DEBUG-LAYOUT mode=\(mode) sceneYaw=\(sceneYaw * 180 / .pi)도 scale=\(sceneRoot.scale.x) anchor=\(cockpitAnchor)")
    }

    /// 3인칭 입력 캐처 조각(결정 53 추가). 캐처 로컬: 원점 = 머리, −Z = 기준 방향.
    private static func thirdPersonCatcherShapes() -> [ShapeResource] {
        [
            ShapeResource.generateBox(size: SIMD3(40, 0.6, 40)).offsetBy(translation: SIMD3(0, -1.4, 0)),   // 바닥 슬래브: 윗면 눈높이 −1.1 m
            ShapeResource.generateBox(size: SIMD3(40, 40, 0.6)).offsetBy(translation: SIMD3(0, 0, -15)),    // 앞 벽: 기준 방향 15 m
        ]
    }

    /// 미니맵 마커(카트 복제본)의 가장 긴 변. 디자인 PRD 6장 "약 1.5 cm"(지름 0.24 m 테이블 기준 미니맵 로컬).
    private var minimapMarkerLength: Float { 0.015 }

    /// 미니맵 배치(결정 48): 디오라마 = 박스 앞오른쪽 모서리 위에 작게(테크 PRD 9장의 "우측 하단 모서리 안쪽, 트랙 위에
    /// 떠 있게"를 0.7 m 박스에 맞춘 값), 콕핏 = 모드에 들어온 순간 머리 기준 HUD 오른쪽 아래에 사용자 쪽으로 35° 기울여.
    /// 지도 내용(`mapRoot`)은 씬 yaw만큼 돌려 박스/콕핏에서 보이는 트랙 방향과 맞춘다(3인칭은 진입 시점 값 고정 — 북쪽 고정식).
    @MainActor
    private func layoutMinimap() {
        guard let minimap else { return }
        minimap.mapRoot.orientation = simd_quatf(angle: sceneYaw, axis: [0, 1, 0])
        if mode == .diorama {
            let s = minimapDioramaDiameter / minimapTableDiameter
            minimap.root.scale = SIMD3(repeating: s)
            minimap.root.position = boxPosition + SIMD3(boxSize.x / 2 - minimapDioramaDiameter / 2 - 0.02, -boxSize.y / 2 + 0.07, boxSize.z / 2 - minimapDioramaDiameter / 2 - 0.02)
            minimap.root.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        } else {
            let head = currentHeadPose() ?? (position: cockpitAnchor, yaw: Float(0))
            let forward = ScenePlacement.forward(heading: head.yaw)
            let right = SIMD3<Float>(cos(head.yaw), 0, -sin(head.yaw))
            minimap.root.scale = .one
            minimap.root.position = head.position + forward * 1.2 + right * thirdPersonMinimapRight + SIMD3(0, -thirdPersonMinimapDown, 0)
            // 로컬 +Z(랩 텍스트 쪽)가 사용자를 향하도록 yaw를 맞추고, 상판을 사용자 쪽으로 35° 기울인다.
            minimap.root.orientation = simd_quatf(angle: head.yaw, axis: [0, 1, 0]) * simd_quatf(angle: 35 * .pi / 180, axis: [1, 0, 0])
        }
    }

    /// 3인칭 추적 카메라(결정 44~47·49, Issue #25): 기준 방향(`chaseReference.forwardYaw`, 진입 순간 머리 yaw)으로
    /// 2.5 m 앞·1.8 m 아래에 카트가 오도록 씬 루트를 평행이동하고, 씬 yaw는 "카트 heading이 기준 방향을 향하게"
    /// 2.5/s로 평활 회전한다(카트 뒤에서 앞을 본다). 머리 yaw는 카메라에 쓰지 않고 리센터 판정에만 쓴다 —
    /// 고개를 ±45° 돌려도 아무것도 따라오지 않고, ±60°를 2초 넘게 벗어나 있으면 기준이 머리 쪽으로 1.0/s로 옮겨 간다.
    @MainActor
    private func followKart(headYaw: Float?, deltaTime: Float) {
        guard mode == .thirdPerson, track != nil else { return }
        chaseReference.update(headYaw: headYaw, deltaTime: deltaTime, tuning: cockpitTuning)
        let reference = chaseReference.forwardYaw
        let chaseYaw = ScenePlacement.chaseSceneYaw(kartHeading: rail.heading, referenceYaw: reference)
        sceneYaw = ScenePlacement.approachAngle(from: sceneYaw, to: chaseYaw, rate: cockpitTuning.thirdPersonChaseYawRate, deltaTime: deltaTime)
        sceneRoot.orientation = simd_quatf(angle: sceneYaw, axis: [0, 1, 0])
        let target = ScenePlacement.cockpitTarget(anchor: cockpitAnchor, mode: mode, referenceYaw: reference, tuning: cockpitTuning)
        // 카트의 3D 위치(루프·언덕이면 y 포함)를 콕핏 목표점에 둔다 — 세계가 평행이동만 하고(회전은 yaw뿐) 카트가 오르면 세계가 내려간다.
        let kartLocal = latestPose.position
        sceneRoot.position = ScenePlacement.rootPosition(placing: kartLocal, at: target, yaw: sceneYaw, scale: 1)
        inputCatcher.orientation = simd_quatf(angle: reference, axis: [0, 1, 0]) // 앞 벽이 기준 방향(리센터 포함)을 따라간다
        followHUD(deltaTime: deltaTime)
    }

    /// 종료 안전망(결정 53 추가): 3인칭에서 차를 세우고 양손을 다 뗀 채 `menuWindowReopenAfter`초가 지나면 숨겨 둔 메뉴 창을
    /// 사용자 정면에 다시 연다. HUD 버튼이 어떤 이유로든 안 눌려도 시스템 창의 "박스 닫기"로 나갈 수 있다(디지털 크라운
    /// 길게 누르기 → 홈은 visionOS 공통 탈출구). 다시 핀치하면 타이머는 0으로 돌아간다.
    @MainActor
    private func updateExitSafetyNet(drive: DriveState, left: HandStatus, right: HandStatus, deltaTime: Float) {
        guard mode == .thirdPerson, immersiveSession.menuWindowHidden else { stoppedHandsFreeSeconds = 0; return }
        let stopped = abs(rail.speed) < 0.05 && drive == .stopped && !left.pinching && !right.pinching
        stoppedHandsFreeSeconds = stopped ? stoppedHandsFreeSeconds + deltaTime : 0
        if stoppedHandsFreeSeconds >= menuWindowReopenAfter {
            openWindow(id: AppScene.menuWindowID)
            immersiveSession.menuWindowHidden = false
            stoppedHandsFreeSeconds = 0
            print("DEBUG-EXIT 정지 + 양손 해제 \(menuWindowReopenAfter)초 → 메뉴 창 재오픈(종료 안전망)")
        }
    }

    /// 3인칭에서 HUD·미니맵을 머리 앞에 **느리게 따라오게**(결정 53, 실기기: 차를 세운 뒤 HUD 버튼을 호버할 수 없어 탈출
    /// 경로가 없었다 — 모드 진입 순간 위치에 고정돼 있어 몸을 돌리거나 자리를 옮기면 시야 밖에 남았다). visionOS 시스템
    /// UI처럼 4/s 지수 평활로 따라와 운전 중에는 거의 가만히 있고, 고개를 크게 돌리면 1초쯤 뒤 다시 앞에 온다.
    @MainActor
    private func followHUD(deltaTime: Float) {
        guard mode == .thirdPerson, deltaTime > 0, let head = currentHeadPose() else { return }
        hudFollowYaw = ScenePlacement.approachAngle(from: hudFollowYaw, to: head.yaw, rate: hudFollowRate, deltaTime: deltaTime)
        let alpha = 1 - exp(-hudFollowRate * deltaTime)
        let forward = ScenePlacement.forward(heading: hudFollowYaw)
        let right = SIMD3<Float>(cos(hudFollowYaw), 0, -sin(hudFollowYaw))
        if let hudEntity {
            let goal = head.position + forward * 1.2 + SIMD3(0, -0.15, 0)
            hudEntity.position += (goal - hudEntity.position) * alpha
        }
        if let minimap {
            let goal = head.position + forward * 1.2 + right * thirdPersonMinimapRight + SIMD3(0, -thirdPersonMinimapDown, 0)
            minimap.root.position += (goal - minimap.root.position) * alpha
            minimap.root.orientation = simd_quatf(angle: hudFollowYaw, axis: [0, 1, 0]) * simd_quatf(angle: 35 * .pi / 180, axis: [1, 0, 0])
        }
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
        hudLoopLastTick = CACurrentMediaTime()
        while !Task.isCancelled {
            try? await Task.sleep(for: hudUpdateInterval)
            // 실제 경과 시간을 쓴다 — 고정 0.25초를 더하면 랩 타임이 폴링 주기로 양자화되고 누락된 틱만큼 짧아진다(결정 56).
            let now = CACurrentMediaTime()
            let elapsed = min(max(now - hudLoopLastTick, 0), 1.0)
            hudLoopLastTick = now
            let wasFinished = raceModel.isFinished
            raceModel.updateDrive(latestDrive, left: latestLeftStatus, right: latestRightStatus)
            raceModel.updateMotion(speedMetersPerSecond: latestSpeed, deltaTime: elapsed)
            raceModel.updateLap(latestLapProgress, totalCheckpoints: latestCheckpointCount)
            raceModel.setRespawning(latestIsOffTrack)
            raceModel.updateMap(position: latestMapPosition, heading: latestHeading)
            if raceModel.isFinished && !wasFinished {
                recordResult()
            }
        }
    }

    /// 완주 결과 확정 + 트랙·카트별 최고 기록(`UserDefaults`) 갱신. HUD가 결과 패널로 바뀐다(Issue #42).
    @MainActor
    private func recordResult() {
        guard let track else { return }
        let hud = raceModel.hud
        let key = "bestTotalTime.\(track.id).\(selection.selectedKartID)"
        let previousBest = UserDefaults.standard.object(forKey: key) as? Double
        let isNewRecord = previousBest.map { hud.totalTime < $0 } ?? true
        if isNewRecord { UserDefaults.standard.set(hud.totalTime, forKey: key) }
        raceResult = RaceResult(
            totalTime: hud.totalTime, lapTimes: hud.lapTimes, bestLapTime: hud.bestLapTime,
            previousBestTotalTime: previousBest, isNewRecord: isNewRecord,
            kartName: selection.selectedKart.displayName, trackName: track.name
        )
        print("DEBUG-RACE 완주 total=\(hud.totalTime) laps=\(hud.lapTimes) best=\(String(describing: previousBest)) new=\(isNewRecord)")
    }

    /// 일시정지(Issue #44, 목업 06): 주행 중에만. 타이머(`RaceModel`)·주행 적분(`tickMotion`)이 멈추고 엔진은 `paused()`,
    /// 배경음은 −10 dB. HUD는 일시정지 패널(재개·다시 시작·박스 닫기)로 바뀐다. 3인칭 종료 안전망(정지+양손 해제 4초 → 메뉴 창)은
    /// 패널을 못 누를 때의 예비 경로로 남겨 둔다 — 일시정지 중에도 손을 떼고 있으면 그대로 동작한다.
    @MainActor
    private func pauseRace() {
        guard raceModel.isRacing, !raceLocked else { return }
        isPaused = true
        raceLocked = true
        raceModel.pause()
        engineAudioPlayer?.run(engineMachine.paused())
        bgmPlayer.duck(true)
    }

    /// 재개: 3·2·1·GO를 다시 탄 뒤 입력이 풀린다. 기록·랩·곡은 그대로.
    @MainActor
    private func resumeRace() {
        guard isPaused else { return }
        startCountdown(resuming: true)
    }

    /// 다시 하기(Issue #42): 출발 위치로 되돌리고 랩·이탈·트레일을 초기화한 뒤 카운트다운부터 다시 시작한다.
    @MainActor
    private func restartRace() {
        guard let track, let trackSpline else { return }
        rail = RailMotionState(startOn: trackSpline, frameIndex: track.start.pathIndex)
        latestPose = rail.pose(on: trackSpline)
        lapTracker = LapTracker(track: track)
        trailRoot.children.removeAll()
        lastTrailDisplayPoint = nil
        raceResult = nil
        latestLapProgress = LapProgress()
        engineAudioPlayer?.run(engineMachine.respawned())
        raceModel.start(totalLaps: track.laps)
        if mode == .thirdPerson { applyModeLayout() } // 기준 방향·씬 yaw를 새 출발 heading에 맞춘다
        startCountdown()
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

    /// 선택된 트랙(`selection.selectedTrackID`, 번들의 `track_XX.json`)을 읽어 월드→박스 배율과 출발 상태를 잡는다.
    /// 타일 3D 배치·미니맵은 `buildTrackScenery()`가 비동기로 따로 한다(디자인 결정 36-4).
    @MainActor
    private func loadTrack() {
        let trackID = selection.selectedTrackID
        guard let definition = TrackCatalog.track(id: trackID) ?? TrackCatalog.tracks.first else {
            // 번들에 트랙 JSON이 하나도 없으면 여기서 끝난다 — 씬 루트 변환·타일·카트 배치가 전부 건너뛰어져 "박스를 열어도
            // 아무것도 안 보이는" 증상이 된다(2026-10-12 실기기, 결정 58 추가). Resources/Tracks 복사 누락을 의심할 것.
            print("DEBUG-TRACK 카탈로그에 트랙이 없다(selected=\(trackID), bundle=\(TrackCatalog.tracks.map(\.id))) — Resources/Tracks 확인")
            return
        }
        guard let spline = TrackSpline(track: definition) else {
            print("DEBUG-TRACK \(definition.id): 스플라인을 만들 수 없다(path \(definition.path.count)점, frames \(definition.frames?.count ?? 0))")
            return
        }
        let path = TrackPath(definition)

        let xs = path.points.map(\.x)
        let zs = path.points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minZ = zs.min(), let maxZ = zs.max() else { return }
        let worldSpan = max(maxX - minX, max(maxZ - minZ, 0.001))

        track = definition
        trackPath = path
        trackSpline = spline
        loadedTrackID = trackID
        lapTracker = LapTracker(track: definition)
        trailRoot.children.removeAll()
        lastTrailDisplayPoint = nil
        raceResult = nil
        latestLapProgress = LapProgress()
        // 배율: 평면 바운딩 박스가 `trackFootprint`에 맞고, 루프·다리 높이도 박스 안(`boxSize.y` 안쪽)에 들어가야 한다.
        trackDisplayScale = min(trackFootprint / worldSpan, (boxSize.y - 0.08) / max(spline.maxHeight, 0.01))
        trackWorldCenter = SIMD2((minX + maxX) / 2, (minZ + maxZ) / 2)

        rail = RailMotionState(startOn: spline, frameIndex: definition.start.pathIndex)
        latestPose = rail.pose(on: spline)
        raceModel.start(totalLaps: definition.laps)
        applyModeLayout()
        startCountdown()
    }

    /// 타일(씬 루트 아래 `trackTilesRoot`)과 미니맵(월드 앵커 아래)을 현재 `track`으로 짓는다. 이미 있으면 먼저 치운다.
    @MainActor
    private func buildTrackScenery() async {
        trackTilesRoot.children.removeAll()
        minimap?.root.removeFromParent()
        minimap = nil
        guard let track, let trackPath else { return }
        if let model = track.model, let url = Bundle.main.url(forResource: model, withExtension: "usdz") {
            // 서킷(스키마 2, 결정 58): Blender가 구운 노면 USDZ 한 덩어리(`Tools/build_circuit.py`). 트랙 좌표계 그대로.
            do {
                let entity = try await Entity(contentsOf: url)
                entity.name = model
                trackTilesRoot.addChild(entity)
            } catch {
                print("서킷 모델 로드 실패(\(model)): \(error)")
            }
        } else {
            await buildTrackTiles(definition: track, into: trackTilesRoot)
        }
        let built = await MinimapBuilder.make(track: track, path: trackPath, tableDiameter: minimapTableDiameter)
        worldAnchor.addChild(built.root)
        minimap = built
        if let kart = loadedKartEntity {
            built.setMarker(cloneOf: kart, markerLength: minimapMarkerLength)
        }
        layoutMinimap()
    }

    /// 박스가 열린 채로 메뉴 창에서 트랙을 바꿨을 때(Issue #43): 타일·미니맵·출발 위치를 다시 만들고 카운트다운부터.
    /// 배경음은 `startCountdown()`이 0.5초 페이드로 끈다(배경음 규칙 "트랙 선택 0.5초").
    @MainActor
    private func reloadTrack() async {
        countdownTask?.cancel()
        engineAudioPlayer?.run(engineMachine.respawned())
        loadTrack()
        await buildTrackScenery()
    }

    /// `Assets/sfx/ENGINE.md` 3-4장: 카운트다운 시작(`countdownTick` 3회) → GO. 시동(`engineIgnition`)은
    /// 카운트다운과 동시에 시작해 2.2초 뒤 공회전으로 넘어간다 — 별도 타이밍이라 병렬로 돈다.
    /// 3·2·1·GO (Issue #41): 그동안 `raceLocked`로 입력을 잠그고, HUD는 `raceModel.hud.phase`의 숫자를 크게 보여 준다.
    /// `resuming`(Issue #44): 일시정지에서 돌아올 때는 기록·곡을 그대로 두고 카운트다운만 다시 탄다 — 배경음은 −10 dB에서
    /// GO에 원래 음량으로, 엔진은 `resumed()`로 공회전부터.
    private func startCountdown(resuming: Bool = false) {
        raceLocked = true
        showsGoFlash = false
        countdownTask?.cancel()
        if !resuming {
            isPaused = false
            bgmPlayer.stop(fadeOut: 0.5) // 카운트다운 동안은 배경음 없음(다시 하기·트랙 선택으로 들어와도 마찬가지)
            engineAudioPlayer?.run(engineMachine.countdownStarted())
        }
        countdownTask = Task { @MainActor in
            for remaining in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                raceModel.countdown(remaining)
                sfxPlayer?.play(.countdownTick)
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            raceModel.go()
            sfxPlayer?.play(.go)
            if resuming {
                isPaused = false
                bgmPlayer.duck(false)
                engineAudioPlayer?.run(engineMachine.resumed(pedal: 0, isHolding: false, speed: Double(abs(rail.speed))))
            } else {
                bgmPlayer.startNextTrack(fadeIn: 1.0) // GO 효과음과 동시에 1.0초 페이드 인, 레이스마다 다음 곡
            }
            raceLocked = false
            showsGoFlash = true
            try? await Task.sleep(for: .seconds(0.6))
            showsGoFlash = false
        }
    }

    /// 트랙 그리드 전체를 실제 타일 3D 모델(`tile_straight`/`tile_curve`/`tile_start`/`tile_grass`)로
    /// 깐다 — 디자인 결정 36-4로 타일 에셋이 도착해서, 점열 placeholder(이전 구현)를 대체한다.
    /// `tiles`에 없는 칸은 전부 잔디로 채운다.
    @MainActor
    private func buildTrackTiles(definition: TrackDefinition, into parent: Entity) async {
        guard !definition.tiles.isEmpty else { return }
        // 씬 루트는 트랙 좌표계다: 타일 바닥이 y = 0, 노면 윗면은 `track.roadSurfaceHeight`(4 m 타일에서 0.25 m).
        // 박스 바닥 높이·배율은 `applyModeLayout()`이 씬 루트 변환으로 준다.
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
        let floorY: Float = (track?.roadSurfaceHeight ?? 0) + 0.03
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

    /// 헤드 앵커 위치에 구슬을, 기기 정면 방향으로 막대를 띄운다(디버그 시각화, 결정 21번). 돌려주는 값은
    /// **씬(월드) 좌표계** 머리 yaw다 — 3인칭 카메라 기준 리센터 판정(`ChaseCameraReference`)에만 쓰고, 조향에는
    /// 쓰지 않는다(1인칭 머리 조향은 결정 47·49로 폐기).
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
    private func tickMotion(deltaTime: Float, headYaw: Float?) {
        guard deltaTime > 0, let track, let trackSpline, let lapTracker else { return }

        // `ingest()`에서 찍는 시계(CACurrentMediaTime)와 반드시 같은 기준이어야 한다. 섞어 쓰면
        // HandInputResolver의 스테일 판정이 항상 틀어진다(결정 24번).
        let now = CACurrentMediaTime()
        let (resolvedDrive, leftStatus, rightStatus) = inputResolver.resolve(now: now, mode: mode)
        // 카운트다운 중·완주 뒤에는 입력을 무시한다(결정 56). 손 상태 자체는 HUD에 그대로 보여 준다.
        let drive: DriveState = raceLocked ? .stopped : resolvedDrive
        let tuning = MotionTuning().applying(track.tuning)
        let previousSpeed = rail.speed
        // 일시정지 중에는 주행 시간을 0으로 흘려 속도·위치가 그대로 멈춘다(Issue #44). HUD 추종·손 상태 표시는 계속.
        let motionDelta: Float = isPaused ? 0 : deltaTime
        // 레일 주행(결정 58): 중심선 호 길이·가로 오프셋·상대 yaw로 적분한다. 코너 곡률(핸들 안 꺾으면 바깥 벽), 안쪽 라인 보정,
        // 중력(루프·언덕: 스로틀 없이는 미끄러짐), 벽 충돌은 전부 `RailMotionState` 안에서 처리된다.
        let step = rail.advancing(drive: drive, tuning: tuning, spline: trackSpline, deltaTime: motionDelta)
        rail = step.state
        let pose = rail.pose(on: trackSpline)
        latestPose = pose
        // 카트 리그(핸들·차체 기울기·바퀴, Issue #26): 손 입력과 속도 변화로 부품을 돌린다.
        kartRig?.update(drive: drive, speed: rail.speed, maxSpeed: tuning.maxSpeed, acceleration: (rail.speed - previousSpeed) / deltaTime, deltaTime: deltaTime)

        let pathIndex = trackSpline.frameIndex(at: rail.s)
        let previousProgress = lapTracker.progress
        lapTracker.update(pathIndex: pathIndex)
        let newProgress = lapTracker.progress

        // 효과음: 완주 > 랩 완료 > 체크포인트 순으로 우선순위를 둔다(동시에 일어나면 완주가 제일 중요하다).
        if !previousProgress.isFinished && newProgress.isFinished {
            sfxPlayer?.play(.finish)
            engineAudioPlayer?.run(engineMachine.finished())
            bgmPlayer.stop(fadeOut: 2.0) // 완주: `finish` 효과음과 동시에 2.0초 페이드 아웃
            raceLocked = true // 완주: 입력 무시, 관성으로 서서히 정지. 결과 패널은 HUD 루프가 띄운다.
        } else if newProgress.currentLap != previousProgress.currentLap {
            sfxPlayer?.play(.lapComplete)
        } else if newProgress.checkpointsPassedThisLap > previousProgress.checkpointsPassedThisLap {
            sfxPlayer?.play(.checkpoint)
        }
        if step.hitWall {
            sfxPlayer?.play(.wallBump)
        }

        updateExitSafetyNet(drive: drive, left: leftStatus, right: rightStatus, deltaTime: deltaTime)

        latestDrive = drive
        latestLeftStatus = leftStatus
        latestRightStatus = rightStatus
        latestSpeed = rail.speed
        latestLapProgress = newProgress
        latestCheckpointCount = track.checkpoints.count
        latestIsOffTrack = false // 레일 위라 트랙 이탈이 없다(벽이 막는다). 리스폰은 폐기(결정 58).

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
        }
        let engineCommands = engineMachine.update(
            dt: Double(deltaTime),
            pedal: pedalMagnitude,
            isHolding: isHolding,
            speed: Double(rail.speed),
            maxSpeed: Double(tuning.maxSpeed)
        )
        engineAudioPlayer?.run(engineCommands)

        // 카트는 씬 루트(트랙 좌표계) 안에서 트랙 좌표 그대로 움직인다. 표시 배율·회전·콕핏 따라붙기는 씬 루트 몫.
        // 자세는 노면 프레임(위치는 노면 위, 루프에서는 높이·거꾸로까지) + 상대 yaw — `KartPose.orientation`.
        kartSlot.position = pose.position
        kartSlot.orientation = pose.orientation
        followKart(headYaw: headYaw, deltaTime: deltaTime)

        // 미니맵 동기화(테크 PRD 9장 `MinimapSyncSystem` 역할): 마커 위치·회전, 체크포인트 라벨 색, 랩 텍스트.
        let kartTrackPosition = SIMD2(pose.position.x, pose.position.z)
        if let minimap {
            minimap.update(kartWorldXZ: kartTrackPosition, heading: pose.heading, progress: newProgress, totalLaps: track.laps)
            latestMapPosition = minimap.projection.mapPosition(kartTrackPosition)
        }
        latestHeading = pose.heading

        // 디버그: 실제로 이동한 거리를 빨간 선으로 쌓고, 콘솔에도 주기적으로 남긴다.
        if let last = lastTrailDisplayPoint {
            if simd_distance(last, kartTrackPosition) >= trailMinSegmentLength {
                addTrailSegment(from: last, to: kartTrackPosition)
                lastTrailDisplayPoint = kartTrackPosition
            }
        } else {
            lastTrailDisplayPoint = kartTrackPosition
        }

        totalDistanceTraveled += abs(rail.speed) * motionDelta
        motionLogAccumulator += deltaTime
        if motionLogAccumulator >= motionLogInterval {
            motionLogAccumulator = 0
            print("DEBUG-MOTION drive=\(drive) speed=\(rail.speed)m/s s=\(rail.s) lateral=\(rail.lateral) yaw=\(rail.yaw * 180 / .pi) pos=\(pose.position) totalDistance=\(totalDistanceTraveled)m")
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
        // 이름 **정확 일치**만 쓴다(Issue #23): 부분 일치 "front"는 razr에서 `front_l`(앞왼 바퀴 묶음, 약 35°)·
        // `front_blade_l`이 먼저 걸려 카트가 옆으로 비틀려 보였다. 후보는 RetireX 원본에서 차 앞을 뜻하는 이름들.
        guard let front = findDescendant(in: entity, namedOneOf: Self.frontMarkerNames) else {
            print("DEBUG-FRONT 정면 마커(\(Self.frontMarkerNames))를 못 찾음 — fallback \(fallbackDegrees)도 사용")
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

    /// 차 앞을 뜻하는 노드 이름(RetireX 원본 그대로, 소문자 비교). 앞에 있는 이름을 우선한다.
    private static let frontMarkerNames = ["front_aero", "race_nose", "nose", "front"]

    private func findDescendant(in entity: Entity, namedOneOf names: [String]) -> Entity? {
        for name in names {
            if let found = findDescendant(in: entity, namedExactly: name) { return found }
        }
        return nil
    }

    private func findDescendant(in entity: Entity, namedExactly name: String) -> Entity? {
        if entity.name.lowercased() == name { return entity }
        for child in entity.children {
            if let found = findDescendant(in: child, namedExactly: name) { return found }
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
            kartRig = KartRig(kart: entity)
            minimap?.setMarker(cloneOf: entity, markerLength: minimapMarkerLength)

            loadedKartID = kart.id
            loadedColorID = colorID
        } catch {
            print("카트 로드 실패(\(kart.usdzResourceName)): \(error)")
        }
    }
}

/// 완주 결과(결정 56, Issue #42). `UserDefaults`에 트랙·카트별 최고 총 시간을 저장한다.
struct RaceResult: Equatable {
    let totalTime: TimeInterval
    let lapTimes: [TimeInterval]
    let bestLapTime: TimeInterval?
    let previousBestTotalTime: TimeInterval?
    let isNewRecord: Bool
    let kartName: String
    let trackName: String
}

/// "0:31.42" 형식(디자인 목업 01·07).
func formatRaceTime(_ t: TimeInterval) -> String {
    let minutes = Int(t) / 60
    let seconds = t - Double(minutes * 60)
    return String(format: "%d:%05.2f", minutes, seconds)
}

/// HUD 패널(M5): 주행 중 랩·타임·속도·핀치 상태, 카운트다운 중 큰 숫자, 완주 뒤 결과 패널(총 시간·랩별·신기록·다시 하기).
/// 배치/스타일은 디자인 목업 04·05·07을 따르되 패널 한 장 구성은 유지(디자인 결정 49-3).
private struct RaceHUDOverlay: View {
    let hud: RaceHUDState
    let mode: ExperienceMode
    let showsGoFlash: Bool
    let result: RaceResult?
    let onModeChange: (ExperienceMode) -> Void
    let onRestart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onTrackSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ModeSwitchView(mode: mode, onModeChange: onModeChange)
            if let result, hud.phase == .finished {
                resultPanel(result)
            } else if hud.phase == .paused {
                pausePanel
            } else {
                racingPanel
            }
            Button("박스 닫기", action: onClose)
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var countdownText: String? {
        if showsGoFlash { return "GO" }
        if case .countdown(let n) = hud.phase { return "\(n)" }
        return nil
    }

    @ViewBuilder
    private var racingPanel: some View {
        if let countdownText {
            // 카운트다운(목업 04): 숫자는 ui-ink, GO는 ui-cyan. 픽셀 폰트(Galmuri14)로 크게.
            Text(countdownText)
                .font(.custom("Galmuri14", size: countdownText == "GO" ? 56 : 72, relativeTo: .largeTitle))
                .foregroundStyle(countdownText == "GO" ? Color.style(StylePalette.uiCyan) : Color.style(StylePalette.uiInk))
                .frame(minHeight: 80)
                .accessibilityLabel(countdownText == "GO" ? "출발" : "카운트다운 \(countdownText)")
        }
        VStack(spacing: 4) {
            Text("LAP \(hud.lap) / \(hud.totalLaps)")
                .font(.headline)
                .foregroundStyle(Color.style(StylePalette.uiInk))
            Text(formatRaceTime(hud.lapTime))
                .font(.title2.monospacedDigit())
                .foregroundStyle(Color.style(StylePalette.uiInk))
            HStack(spacing: 8) {
                Text("총 " + formatRaceTime(hud.totalTime))
                if let best = hud.bestLapTime { Text("BEST " + formatRaceTime(best)) }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.style(StylePalette.uiInk).opacity(0.8))
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
        if hud.phase == .racing {
            Button("일시정지", action: onPause)
                .buttonStyle(.bordered)
        }
    }

    /// 일시정지(목업 06): 멈춘 시점의 랩·총 시간, 재개(주 버튼)·다시 시작. 종료는 아래 공용 "박스 닫기".
    private var pausePanel: some View {
        VStack(spacing: 8) {
            Text("일시정지")
                .font(.custom("Galmuri11-Bold", size: 24, relativeTo: .title2))
                .foregroundStyle(Color.style(StylePalette.uiInk))
            Text("LAP \(hud.lap) / \(hud.totalLaps) · " + formatRaceTime(hud.totalTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.style(StylePalette.uiInk).opacity(0.8))
            HStack(spacing: 8) {
                Button("재개", action: onResume)
                    .buttonStyle(.borderedProminent)
                Button("다시 시작", action: onRestart)
                    .buttonStyle(.bordered)
            }
        }
        .frame(minHeight: 80)
    }

    /// 결과(목업 07): 총 시간 큰 숫자, 랩별 시간, "신기록!" 배지, 다시 하기.
    private func resultPanel(_ result: RaceResult) -> some View {
        VStack(spacing: 6) {
            Text("완주!")
                .font(.custom("Galmuri11-Bold", size: 24, relativeTo: .title2))
                .foregroundStyle(Color.style(StylePalette.uiInk))
            Text(formatRaceTime(result.totalTime))
                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.style(StylePalette.uiInk))
            if result.isNewRecord {
                Text("신기록!")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.style(StylePalette.uiGold), in: Capsule())
                    .foregroundStyle(Color.style(StylePalette.uiNight))
            } else if let previous = result.previousBestTotalTime {
                Text("BEST " + formatRaceTime(previous))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.style(StylePalette.uiInk).opacity(0.8))
            }
            VStack(spacing: 2) {
                ForEach(Array(result.lapTimes.enumerated()), id: \.offset) { index, lap in
                    HStack {
                        Text("LAP \(index + 1)")
                        Spacer(minLength: 16)
                        Text(formatRaceTime(lap))
                            .foregroundStyle(lap == result.bestLapTime ? Color.style(StylePalette.uiCyan) : Color.style(StylePalette.uiInk))
                    }
                    .font(.caption.monospacedDigit())
                }
            }
            .frame(width: 150)
            .foregroundStyle(Color.style(StylePalette.uiInk))
            Text("\(result.kartName) · \(result.trackName)")
                .font(.caption2)
                .foregroundStyle(Color.style(StylePalette.uiInk).opacity(0.7))
            HStack(spacing: 8) {
                Button("다시 하기", action: onRestart)
                    .buttonStyle(.borderedProminent)
                // 목업 07의 "트랙 선택": 메뉴 창의 트랙 카드로 보낸다(3인칭에서는 숨겨 둔 창을 다시 연다, Issue #43).
                Button("트랙 선택", action: onTrackSelect)
                    .buttonStyle(.bordered)
            }
        }
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
