#if os(iOS)
import Foundation
import Observation
import QuartzCore
import RealityKit
import SwiftUI
import UIKit

/// iOS/iPadOS 레이스 장면(결정 60, Issue #47~#50). visionOS `ImmersiveBoxView`와 같은 `KartCore`(트랙 스플라인·레일 주행·랩·HUD 상태·
/// 엔진음 상태 기계)를 쓰고, 다른 것은 **입력(터치)과 카메라(가상 PerspectiveCamera)**뿐이다. 세계는 가만히 있고 카메라가 움직인다.
///
/// 프레임 콜백(`tick`)은 RealityKit 렌더 중에 불리므로 `@Observable` 상태를 직접 건드리지 않고(`@ObservationIgnored` 저장),
/// 별도 루프가 HUD(250 ms)·미니맵(33 ms)으로 옮긴다 — visionOS와 같은 이유("Modifying state during view update").
@MainActor
@Observable
final class RaceSceneController {
    // MARK: 관찰되는 상태(SwiftUI가 읽는다)
    let raceModel = RaceModel()
    private(set) var track: TrackDefinition?
    private(set) var raceResult: RaceResult?
    private(set) var showsGoFlash = false
    private(set) var isPaused = false
    private(set) var cameraMode: CameraViewMode = .chase
    /// 미니맵 마커용(33 ms 갱신).
    private(set) var displayPose = KartPose(position: .zero, forward: SIMD3(0, 0, -1), up: SIMD3(0, 1, 0), heading: 0)
    private(set) var displayCheckpoints = 0
    private(set) var loadError: String?
    /// 랩 진입 배너 파일 이름(결정 65). 1.8초 뒤 사라진다.
    private(set) var lapBanner: String?
    /// 속도계 부스트 기준(km/h, 결정 63).
    private(set) var boostThresholdKmh: Double = 12.96

    // MARK: 입력(터치 존이 쓴다)
    @ObservationIgnored var touch = TouchInputResolver()
    /// 화면 종횡비(가로/세로) — 탑뷰 높이 계산. `RaceScreen`이 GeometryReader로 넣는다.
    @ObservationIgnored var aspect: Float = 0.5

    // MARK: 장면
    /// `content`에 직접 붙는 뿌리. 평소엔 `sceneRoot`가 여기 매달리고, AR에서는 평면 앵커 아래로 옮긴다.
    @ObservationIgnored private let worldRoot = Entity()
    @ObservationIgnored private let sceneRoot = Entity()
    @ObservationIgnored private var skyEntity: Entity?
    @ObservationIgnored private var arAnchor: AnchorEntity?
    @ObservationIgnored private var spatialSession: SpatialTrackingSession?
    @ObservationIgnored private var sceneStarted = false
    @ObservationIgnored private var frameSampler = FrameTimeSampler(interval: 5)
    @ObservationIgnored private let trackProps = TrackProps()
    @ObservationIgnored private var lapBannerTask: Task<Void, Never>?
    @ObservationIgnored private var playedCountdownErrorCue = false
    /// 카운트다운 그림 텍스처(count_3/2/1·go) — 장면 안 평면에 붙인다(결정 65). 없으면 3D 텍스트로 대체.
    @ObservationIgnored private var countdownTextures: [String: TextureResource] = [:]
    /// 카운트다운 숫자를 **장면 안**(카메라 앞 1.2 m)에 3D 텍스트로 띄운다 — SwiftUI 오버레이는 RealityView가 첫 프레임을 그리기
    /// 전(검은 자리표시자) 위에도 보여서 "검은 화면에 3"이 떴다. 장면 안 텍스트는 장면이 보일 때만 보인다(결정 60).
    @ObservationIgnored private let countdownEntity = ModelEntity()
    @ObservationIgnored private var countdownMaterialInk = UnlitMaterial(color: .style(StylePalette.uiInk))
    @ObservationIgnored private var countdownMaterialGo = UnlitMaterial(color: .style(StylePalette.uiCyan))
    @ObservationIgnored private let kartSlot = Entity()
    @ObservationIgnored private let trackRoot = Entity()
    @ObservationIgnored private let camera = PerspectiveCamera()
    @ObservationIgnored private var updateSubscription: EventSubscription?
    @ObservationIgnored private let tileLibrary = TrackTileLibrary()
    @ObservationIgnored private var loadedKartEntity: Entity?
    @ObservationIgnored private var kartRig: KartRig?

    // MARK: 주행
    @ObservationIgnored private let selection: KartSelectionModel
    @ObservationIgnored private var trackSpline: TrackSpline?
    @ObservationIgnored private var lapTracker: LapTracker?
    @ObservationIgnored private var rail = RailMotionState()
    @ObservationIgnored private var latestPose = KartPose(position: .zero, forward: SIMD3(0, 0, -1), up: SIMD3(0, 1, 0), heading: 0)
    @ObservationIgnored private var latestDrive: DriveState = .stopped
    @ObservationIgnored private var latestLeft = HandStatus(tracked: true, pinching: false)
    @ObservationIgnored private var latestRight = HandStatus(tracked: true, pinching: false)
    @ObservationIgnored private var latestProgress = LapProgress()
    @ObservationIgnored private var latestSpeed: Float = 0
    @ObservationIgnored private var raceLocked = true
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var hudTask: Task<Void, Never>?
    @ObservationIgnored private var hudLastTick: TimeInterval = CACurrentMediaTime()
    @ObservationIgnored private var cameraPose = CameraPose(position: SIMD3(0, 5, 10), target: .zero)
    @ObservationIgnored private let cameraTuning = ChaseCameraTuning()
    @ObservationIgnored private var trackBounds: (min: SIMD2<Float>, max: SIMD2<Float>) = (.zero, .zero)

    // MARK: 소리
    @ObservationIgnored private var engineMachine = EngineSoundMachine()
    @ObservationIgnored private var engineAudioPlayer: EngineAudioPlayer?
    @ObservationIgnored private var sfxPlayer: SFXPlayer?
    @ObservationIgnored private let bgmPlayer = BGMPlayer()

    init(selection: KartSelectionModel) {
        self.selection = selection
    }

    // MARK: - 장면 구성

    /// `RealityView`의 make 클로저에서 한 번 호출. 가상 카메라·조명·하늘·트랙·카트를 만들고 카운트다운을 시작한다.
    func setup(content: inout RealityViewCameraContent) async {
        content.camera = .virtual
        sceneRoot.name = "sceneRoot"
        sceneRoot.addChild(trackRoot)
        sceneRoot.addChild(kartSlot)
        worldRoot.addChild(sceneRoot)
        content.add(worldRoot)

        camera.camera.fieldOfViewInDegrees = cameraTuning.fieldOfViewDegrees
        countdownEntity.position = SIMD3(0, 0.08, -1.2)
        countdownEntity.isEnabled = false
        camera.addChild(countdownEntity)
        content.add(camera)

        // 조명: 키 + 필(IBL 없이도 PBR 카트가 어둡지 않게)
        let key = DirectionalLight()
        key.light.intensity = 4000
        key.light.color = .white
        key.look(at: .zero, from: SIMD3(30, 60, 20), relativeTo: nil)
        content.add(key)
        let fill = DirectionalLight()
        fill.light.intensity = 1500
        fill.light.color = UIColor(red: 0.8, green: 0.85, blue: 1, alpha: 1)
        fill.look(at: .zero, from: SIMD3(-40, 30, -30), relativeTo: nil)
        content.add(fill)

        do {
            engineAudioPlayer = try EngineAudioPlayer(kart: kartSlot)
        } catch {
            print("엔진음 로드 실패: \(error)")
        }
        sfxPlayer = SFXPlayer(entity: kartSlot)

        loadTrack()
        await buildTrackScenery()
        await loadKart()
        for name in ["count_3", "count_2", "count_1", "go"] {
            if let cg = RaceBanners.cgImage(named: name), let texture = try? await TextureResource(image: cg, options: .init(semantic: .color)) {
                countdownTextures[name] = texture
            }
        }
        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(deltaTime: Float(event.deltaTime))
        }
        startHUDLoop()
        // 카운트다운은 첫 프레임이 실제로 렌더된 뒤(`tick`의 첫 호출)에 시작한다 — 시뮬레이터에서는 이 클로저가 끝나고도 몇 초 동안
        // 자리표시자(검은 화면+스피너)가 남아 그 위에 "3"이 먼저 떴다(결정 60).
    }

    /// `RealityView`의 update 클로저에서 호출: 시점 모드에 따라 카메라(가상/AR)와 씬 배치를 바꾼다.
    func applyCameraMode(content: inout RealityViewCameraContent) {
        switch cameraMode {
        case .ar:
            content.camera = .spatialTracking
            enterAR()
        case .chase, .topView:
            content.camera = .virtual
            leaveAR()
        }
    }

    /// AR(Issue #51): 수평면 앵커 아래에 디오라마 배율로 씬을 올리고, 하늘 구·가상 카메라를 끈다. 카메라 권한은 시스템이 묻는다.
    private func enterAR() {
        guard arAnchor == nil, let spline = trackSpline else { return }
        if spatialSession == nil {
            let session = SpatialTrackingSession()
            spatialSession = session
            Task { @MainActor [weak self] in
                if let unavailable = await session.run(SpatialTrackingSession.Configuration(tracking: [.plane, .camera])) {
                    if unavailable.missingCameraAuthorization == true { self?.loadError = "AR을 쓰려면 카메라 권한이 필요합니다." }
                    else if unavailable.anchor.contains(.plane) { self?.loadError = "이 기기는 평면 추적을 지원하지 않습니다." }
                }
            }
        }
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2(0.4, 0.4)))
        let span = max(trackBounds.max.x - trackBounds.min.x, trackBounds.max.y - trackBounds.min.y, 0.001)
        let scale = min(0.6 / span, 0.3 / max(spline.maxHeight, 0.01))
        let center = (trackBounds.min + trackBounds.max) / 2
        sceneRoot.removeFromParent()
        sceneRoot.scale = SIMD3(repeating: scale)
        sceneRoot.position = SIMD3(-center.x * scale, 0, -center.y * scale)
        anchor.addChild(sceneRoot)
        worldRoot.addChild(anchor)
        arAnchor = anchor
        skyEntity?.isEnabled = false
        camera.isEnabled = false
        if let kart = loadedKartEntity { KartFitter.fit(kart, maxDimension: 0.12 / scale) }
    }

    private func leaveAR() {
        guard let anchor = arAnchor else { return }
        sceneRoot.removeFromParent()
        sceneRoot.scale = .one
        sceneRoot.position = .zero
        worldRoot.addChild(sceneRoot)
        anchor.removeFromParent()
        arAnchor = nil
        skyEntity?.isEnabled = true
        camera.isEnabled = true
        if let kart = loadedKartEntity { KartFitter.fit(kart, maxDimension: CockpitTuning().kartRealLength) }
    }

    func teardown() {
        if let spatialSession { Task { await spatialSession.stop() } }
        sfxPlayer?.stopAll()
        countdownTask?.cancel()
        hudTask?.cancel()
        updateSubscription?.cancel()
        bgmPlayer.stop(fadeOut: 0.5)
    }

    private func loadTrack() {
        let trackID = selection.selectedTrackID
        guard let definition = TrackCatalog.track(id: trackID) ?? TrackCatalog.tracks.first else {
            loadError = "트랙을 찾을 수 없습니다(\(trackID))"
            return
        }
        guard let spline = TrackSpline(track: definition) else {
            loadError = "트랙 스플라인을 만들 수 없습니다(\(definition.id))"
            return
        }
        track = definition
        trackSpline = spline
        boostThresholdKmh = Double(MotionTuning().applying(definition.tuning).maxSpeed) * 0.9 * 3.6
        lapTracker = LapTracker(track: definition)
        rail = RailMotionState(startOn: spline, frameIndex: definition.start.pathIndex)
        latestPose = rail.pose(on: spline)
        displayPose = latestPose
        raceResult = nil
        let xs = definition.path.map(\.x), zs = definition.path.map(\.z)
        trackBounds = (SIMD2(xs.min() ?? 0, zs.min() ?? 0), SIMD2(xs.max() ?? 0, zs.max() ?? 0))
        raceModel.start(totalLaps: definition.laps)
        // 카메라를 바로 목표 자세에 둔다(첫 프레임에 멀리서 날아오지 않게)
        cameraPose = cameraTarget(deltaTime: 0)
        applyCamera()
    }

    private func buildTrackScenery() async {
        trackRoot.children.removeAll()
        guard let track else { return }
        // 하늘: 테마별 색 구(안쪽 면만 그린다)
        var skyMaterial = UnlitMaterial(color: .style(Self.skyHex(for: track.theme?.id)))
        skyMaterial.faceCulling = .front
        let sky = ModelEntity(mesh: .generateSphere(radius: 400), materials: [skyMaterial])
        trackRoot.addChild(sky)
        skyEntity = sky

        if let model = track.model, let url = Bundle.main.url(forResource: model, withExtension: "usdz") {
            do {
                let entity = try await Entity(contentsOf: url)
                entity.name = model
                trackRoot.addChild(entity)
            } catch {
                loadError = "서킷 모델 로드 실패(\(model)): \(error.localizedDescription)"
            }
        } else {
            await buildTrackTiles(definition: track)
        }
        await trackProps.build(for: track.id, into: trackRoot)
    }

    /// 격자 타일 트랙(스키마 1): `ImmersiveBoxView.buildTrackTiles`와 같은 배치.
    private func buildTrackTiles(definition: TrackDefinition) async {
        guard !definition.tiles.isEmpty else { return }
        var occupied = Set<Int>()
        func cellKey(_ col: Int, _ row: Int) -> Int { row * definition.grid.cols + col }
        let cols = definition.tiles.map(\.col), rows = definition.tiles.map(\.row)
        guard let c0 = cols.min(), let c1 = cols.max(), let r0 = rows.min(), let r1 = rows.max() else { return }
        for tile in definition.tiles {
            occupied.insert(cellKey(tile.col, tile.row))
            await placeTile(type: tile.type, col: tile.col, row: tile.row, rotationDegrees: -Float(tile.rot), tileSize: definition.tileSize)
        }
        for row in r0...r1 {
            for col in c0...c1 where !occupied.contains(cellKey(col, row)) {
                await placeTile(type: "grass", col: col, row: row, rotationDegrees: 0, tileSize: definition.tileSize)
            }
        }
    }

    private func placeTile(type: String, col: Int, row: Int, rotationDegrees: Float, tileSize: Float) async {
        guard let entity = await tileLibrary.makeTile(type: type) else { return }
        let center = SIMD2(Float(col) * tileSize + tileSize / 2, -(Float(row) * tileSize + tileSize / 2))
        entity.position = SIMD3(center.x, 0, center.y)
        entity.orientation = simd_quatf(angle: rotationDegrees * .pi / 180, axis: [0, 1, 0])
        trackRoot.addChild(entity)
    }

    private func loadKart() async {
        let kart = selection.selectedKart
        guard let url = Bundle.main.url(forResource: kart.usdzResourceName, withExtension: "usdz") else {
            loadError = "카트 리소스를 찾을 수 없습니다(\(kart.usdzResourceName))"
            return
        }
        do {
            let entity = try await Entity(contentsOf: url)
            await KartMaterialPainter.applyColor(selection.selectedColorID, kart: kart, to: entity)
            entity.orientation = simd_quatf(angle: KartForwardMarker.correctionAngle(for: entity, fallbackDegrees: kart.modelForwardCorrectionDegrees), axis: [0, 1, 0])
            KartFitter.fit(entity, maxDimension: CockpitTuning().kartRealLength)
            kartSlot.children.removeAll()
            kartSlot.addChild(entity)
            loadedKartEntity = entity
            kartRig = KartRig(kart: entity)
            await DriverRig.attach(to: entity, kartID: kart.id)
        } catch {
            loadError = "카트 로드 실패: \(error.localizedDescription)"
        }
    }

    private static func skyHex(for themeID: String?) -> String {
        switch themeID {
        case "neon": return "050815"
        case "canyon": return "F2C98A"
        case "park": return "8FC8F0"
        default: return "9FB7D9"
        }
    }

    // MARK: - 레이스 흐름(visionOS 결정 56·57과 같은 규칙)

    private func startCountdown(resuming: Bool = false) {
        raceLocked = true
        showsGoFlash = false
        countdownTask?.cancel()
        sfxPlayer?.stopAll()
        playedCountdownErrorCue = false
        lapBanner = nil
        if !resuming {
            isPaused = false
            bgmPlayer.stop(fadeOut: 0.5)
            engineAudioPlayer?.run(engineMachine.countdownStarted())
        }
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for remaining in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                raceModel.countdown(remaining)
                showCountdown("\(remaining)", go: false)
                sfxPlayer?.play(.countdownTick)
                try? await Task.sleep(for: .seconds(RaceTiming.countdownStepSeconds))
            }
            guard !Task.isCancelled else { return }
            raceModel.go()
            showCountdown("GO", go: true)
            sfxPlayer?.play(.go)
            if resuming {
                isPaused = false
                bgmPlayer.duck(false)
                engineAudioPlayer?.run(engineMachine.resumed(pedal: 0, isHolding: false, speed: Double(abs(rail.speed))))
            } else {
                bgmPlayer.startNextTrack(fadeIn: 1.0)
            }
            raceLocked = false
            showsGoFlash = true
            try? await Task.sleep(for: .seconds(RaceTiming.goFlashSeconds))
            showsGoFlash = false
            showCountdown(nil, go: false)
        }
    }

    private func showLapBanner(lap: Int, totalLaps: Int) {
        guard let name = RaceBanners.lapBannerName(lap: lap, totalLaps: totalLaps) else { return }
        lapBanner = name
        lapBannerTask?.cancel()
        lapBannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(RaceTiming.lapBannerSeconds))
            if !Task.isCancelled { self?.lapBanner = nil }
        }
    }

    /// 카메라 앞 3D 텍스트 갱신. `nil`이면 숨긴다. 글꼴은 HUD와 같은 Galmuri14(없으면 시스템 볼드).
    private func showCountdown(_ text: String?, go: Bool) {
        guard let text else { countdownEntity.isEnabled = false; return }
        if let name = RaceBanners.countdownImageName(for: text), let texture = countdownTextures[name] {
            // 디자인 전달 픽셀 그림(결정 65): 카메라 앞 1.2 m에 높이 0.32 m 평면으로.
            let aspect = Float(texture.width) / Float(max(texture.height, 1))
            let height: Float = go ? 0.26 : 0.32
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: 1.0)
            material.opacityThreshold = 0.5
            countdownEntity.model = ModelComponent(mesh: .generatePlane(width: height * aspect, height: height), materials: [material])
            countdownEntity.position = SIMD3(0, 0.08, -1.2)
            countdownEntity.isEnabled = true
            return
        }
        let size: CGFloat = go ? 0.22 : 0.3
        let font = UIFont(name: "Galmuri14", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.01, font: font, containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping)
        countdownEntity.model = ModelComponent(mesh: mesh, materials: [go ? countdownMaterialGo : countdownMaterialInk])
        let bounds = mesh.bounds
        countdownEntity.position = SIMD3(-bounds.center.x, 0.08 - bounds.center.y, -1.2)
        countdownEntity.isEnabled = true
    }

    func pause() {
        guard raceModel.isRacing, !raceLocked else { return }
        showCountdown(nil, go: false)
        isPaused = true
        raceLocked = true
        raceModel.pause()
        engineAudioPlayer?.run(engineMachine.paused())
        bgmPlayer.duck(true)
    }

    func resume() {
        guard isPaused else { return }
        startCountdown(resuming: true)
    }

    func restart() {
        guard let track, let trackSpline else { return }
        countdownTask?.cancel()
        rail = RailMotionState(startOn: trackSpline, frameIndex: track.start.pathIndex)
        latestPose = rail.pose(on: trackSpline)
        lapTracker = LapTracker(track: track)
        raceResult = nil
        latestProgress = LapProgress()
        engineAudioPlayer?.run(engineMachine.respawned())
        raceModel.start(totalLaps: track.laps)
        startCountdown()
    }

    func setCameraMode(_ mode: CameraViewMode) {
        cameraMode = mode
        if mode != .ar, loadError?.contains("AR") == true || loadError?.contains("평면") == true { loadError = nil }
    }

    private func recordResult() {
        guard let track else { return }
        let hud = raceModel.hud
        let key = TrackCatalog.bestTotalTimeKey(trackID: track.id, kartID: selection.selectedKartID)
        let previousBest = UserDefaults.standard.object(forKey: key) as? Double
        let isNewRecord = previousBest.map { hud.totalTime < $0 } ?? true
        if isNewRecord {
            UserDefaults.standard.set(hud.totalTime, forKey: key)
            sfxPlayer?.play(.record)
        }
        raceResult = RaceResult(
            totalTime: hud.totalTime, lapTimes: hud.lapTimes, bestLapTime: hud.bestLapTime,
            previousBestTotalTime: previousBest, isNewRecord: isNewRecord,
            kartName: selection.selectedKart.displayName, trackName: track.name
        )
    }

    private func startHUDLoop() {
        hudTask?.cancel()
        hudLastTick = CACurrentMediaTime()
        hudTask = Task { @MainActor [weak self] in
            var minimapAccumulator: TimeInterval = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self else { return }
                let now = CACurrentMediaTime()
                let elapsed = min(max(now - hudLastTick, 0), 1.0)
                hudLastTick = now
                minimapAccumulator += elapsed
                displayPose = latestPose
                displayCheckpoints = latestProgress.checkpointsPassedThisLap
                if minimapAccumulator >= 0.25 {
                    minimapAccumulator = 0
                }
                let wasFinished = raceModel.isFinished
                raceModel.updateDrive(latestDrive, left: latestLeft, right: latestRight)
                raceModel.updateMotion(speedMetersPerSecond: latestSpeed, deltaTime: elapsed)
                raceModel.updateLap(latestProgress, totalCheckpoints: track?.checkpoints.count ?? 0)
                if raceModel.isFinished && !wasFinished { recordResult() }
            }
        }
    }

    // MARK: - 프레임

    private func tick(deltaTime: Float) {
        guard deltaTime > 0, let track, let trackSpline, let lapTracker else { return }
        if !sceneStarted {
            sceneStarted = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                self?.startCountdown()
            }
        }
        var (resolvedDrive, left, right) = touch.resolve()
        if DemoLaunch.autopilot {
            // 데모 촬영(결정 66): 통합 테스트와 같은 자동 조향으로 달린다(DEBUG 전용, 시뮬레이터 캡처용).
            resolvedDrive = Autopilot.drive(state: rail, spline: trackSpline)
        }
        let drive: DriveState = raceLocked ? .stopped : resolvedDrive
        if raceLocked, !isPaused, !raceModel.isFinished, resolvedDrive != .stopped, !playedCountdownErrorCue, !DemoLaunch.autopilot {
            playedCountdownErrorCue = true
            sfxPlayer?.play(.error)
        }
        let tuning = MotionTuning().applying(track.tuning)
        let previousSpeed = rail.speed
        let motionDelta: Float = isPaused ? 0 : deltaTime
        trackProps.update(deltaTime: motionDelta)
        let step = rail.advancing(drive: drive, tuning: tuning, spline: trackSpline, deltaTime: motionDelta)
        rail = step.state
        let pose = rail.pose(on: trackSpline)
        latestPose = pose
        kartRig?.update(drive: drive, speed: rail.speed, maxSpeed: tuning.maxSpeed, acceleration: (rail.speed - previousSpeed) / deltaTime, deltaTime: deltaTime)

        let previous = lapTracker.progress
        lapTracker.update(pathIndex: trackSpline.frameIndex(at: rail.s))
        let progress = lapTracker.progress
        if !previous.isFinished && progress.isFinished {
            sfxPlayer?.play(.finish)
            engineAudioPlayer?.run(engineMachine.finished())
            bgmPlayer.stop(fadeOut: 2.0)
            raceLocked = true
        } else if progress.currentLap != previous.currentLap {
            sfxPlayer?.play(.lapComplete)
            showLapBanner(lap: progress.currentLap, totalLaps: track.laps)
        } else if progress.checkpointsPassedThisLap > previous.checkpointsPassedThisLap {
            sfxPlayer?.play(.checkpoint)
        }
        if step.hitWall { sfxPlayer?.play(.wallBump) }

        latestDrive = drive
        latestLeft = left
        latestRight = right
        latestSpeed = rail.speed
        latestProgress = progress

        let pedal: Double
        let holding: Bool
        switch drive {
        case .pedal(let v): pedal = Double(abs(v)); holding = false
        case .turnLeft, .turnRight: pedal = 0; holding = true
        case .stopped, .waiting: pedal = 0; holding = false
        }
        engineAudioPlayer?.run(engineMachine.update(dt: Double(deltaTime), pedal: pedal, isHolding: holding, speed: Double(rail.speed), maxSpeed: Double(tuning.maxSpeed)))

        kartSlot.position = pose.position
        kartSlot.orientation = pose.orientation

        if cameraMode != .ar {
            cameraPose = ChaseCameraRig.follow(current: cameraPose, target: cameraTarget(deltaTime: deltaTime), rate: cameraTuning.followRate, deltaTime: deltaTime)
            applyCamera()
        }
        if let report = frameSampler.record(deltaTime: Double(deltaTime)) {
            debugLog(String(format: "PERF iOS mode=%@ track=%@ fps=%.1f avg=%.2fms worst=%.1fms entities=%d mem=%.0fMB", cameraMode.rawValue, track.id, report.averageFPS, report.averageMilliseconds, report.worstMilliseconds, Self.countEntities(worldRoot), MemoryFootprint.currentMB()))
        }
    }

    private static func countEntities(_ entity: Entity) -> Int {
        1 + entity.children.reduce(0) { $0 + countEntities($1) }
    }

    private func cameraTarget(deltaTime: Float) -> CameraPose {
        switch cameraMode {
        case .chase:
            return ChaseCameraRig.chaseTarget(pose: latestPose, tuning: cameraTuning)
        case .topView, .ar:
            return ChaseCameraRig.topView(minXZ: trackBounds.min, maxXZ: trackBounds.max, maxHeight: trackSpline?.maxHeight ?? 0, aspect: aspect, tuning: cameraTuning)
        }
    }

    private func applyCamera() {
        camera.look(at: cameraPose.target, from: cameraPose.position, upVector: cameraPose.up, relativeTo: nil)
    }
}
#endif
