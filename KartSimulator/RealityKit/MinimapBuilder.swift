#if os(visionOS) || os(iOS)
import RealityKit
import UIKit
import simd

/// 미니맵 엔티티 묶음 (M4, 결정 48). `MinimapBuilder.make`가 만들고 `ImmersiveBoxView`가 매 프레임 `update`한다.
/// 디자인 PRD 6장: Diorama 테이블 + 평평한 원판 + 노면/궤적 + 출발 깃발 + 체크포인트 라벨 + 카트 마커 + 랩 텍스트.
/// 상호작용 없음 — `InputTargetComponent`를 붙이지 않아 핀치는 `inputCatcher`로 간다(테크 PRD 9장).
@MainActor
final class Minimap {
    /// 바깥에서 위치·회전·배율을 주는 루트. 로컬 y = 0이 지도 평면(테이블 상판).
    let root = Entity()
    /// 트랙 좌표축으로 그려진 지도 내용. 디오라마의 180° 회전(`sceneYaw`)에 맞추려면 이것만 돌린다.
    let mapRoot = Entity()
    let markerSlot = Entity()
    let projection: MinimapProjection
    private var checkpointDiscs: [ModelEntity] = []
    private var lapText: ModelEntity?
    private var lastLapLabel = ""
    private let passedMaterial: UnlitMaterial
    private let pendingMaterial: UnlitMaterial

    init(projection: MinimapProjection) {
        self.projection = projection
        passedMaterial = UnlitMaterial(color: .style(StylePalette.uiCyan))
        var pending = UnlitMaterial(color: .style(StylePalette.uiInk))
        pending.blending = .transparent(opacity: 0.4)
        pendingMaterial = pending
        root.name = "minimap"
        mapRoot.name = "minimapMap"
        root.addChild(mapRoot)
        mapRoot.addChild(markerSlot)
    }

    fileprivate func setCheckpointDiscs(_ discs: [ModelEntity]) { checkpointDiscs = discs }
    fileprivate func setLapText(_ text: ModelEntity) { lapText = text }

    /// 카트 마커: 실제 카트 모델의 복제본(정면 보정 포함)을 약 1.5 cm로 줄여 넣는다(디자인 PRD 6장).
    func setMarker(cloneOf kart: Entity, markerLength: Float) {
        markerSlot.children.removeAll()
        let marker = kart.clone(recursive: true)
        // 원본은 KartFitter가 트랙 단위로 맞춰 둔 상태라 배율·위치를 다시 잡는다.
        marker.scale = .one
        marker.position = .zero
        KartFitter.fit(marker, maxDimension: markerLength)
        markerSlot.addChild(marker)
    }

    /// 매 프레임: 마커 위치·회전, 체크포인트 라벨 색, 랩 텍스트.
    func update(kartWorldXZ: SIMD2<Float>, heading: Float, progress: LapProgress, totalLaps: Int) {
        let p = projection.mapPosition(kartWorldXZ)
        markerSlot.position = SIMD3(p.x, 0.004, p.y)
        markerSlot.orientation = simd_quatf(angle: heading, axis: [0, 1, 0])

        for (i, disc) in checkpointDiscs.enumerated() {
            let passed = MinimapProjection.isCheckpointPassed(ordinal: i, passedCount: progress.checkpointsPassedThisLap)
            disc.model?.materials = [passed ? passedMaterial : pendingMaterial]
        }

        let label = "\(min(progress.currentLap, totalLaps)) / \(totalLaps)"
        if label != lastLapLabel, let lapText {
            lastLapLabel = label
            lapText.model?.mesh = MinimapBuilder.textMesh(label, size: 0.012)
            MinimapBuilder.centerText(lapText)
        }
    }
}

enum MinimapBuilder {
    /// 모든 치수는 지름 `tableDiameter`(기본 0.24 m) 기준 미니맵 로컬 m. 바깥에서 `root.scale`로 줄여 쓴다.
    @MainActor
    static func make(track: TrackDefinition, path: TrackPath, tableDiameter: Float = 0.24) async -> Minimap {
        let projection = MinimapProjection(points: path.points, trackWidth: track.width, tableDiameter: tableDiameter)
        let minimap = Minimap(projection: projection)
        let radius = tableDiameter / 2

        // 1. 테이블: Apple Diorama 샘플의 받침(`Diorama_Base.usdz`, 샘플 라이선스 — LICENSE 5조). 상판이 y = 0에 오게.
        if let url = Bundle.main.url(forResource: "Diorama_Base", withExtension: "usdz"),
           let base = try? await Entity(contentsOf: url) {
            let bounds = base.visualBounds(relativeTo: base)
            let footprint = max(bounds.extents.x, bounds.extents.z)
            if footprint > 0 {
                let s = tableDiameter / footprint
                base.scale = SIMD3(repeating: s)
                base.position = SIMD3(-bounds.center.x * s, -bounds.max.y * s, -bounds.center.z * s)
            }
            recolor(base, with: SimpleMaterial(color: .style(StylePalette.uiRim), roughness: 0.85, isMetallic: false))
            minimap.root.addChild(base)
        } else {
            // 받침을 못 읽어도 미니맵은 보여야 한다: 단순 원기둥 받침으로 대체.
            let fallback = ModelEntity(
                mesh: .generateCylinder(height: 0.03, radius: radius),
                materials: [SimpleMaterial(color: .style(StylePalette.uiRim), roughness: 0.85, isMetallic: false)]
            )
            fallback.position.y = -0.015
            minimap.root.addChild(fallback)
            debugLog("DEBUG-MINIMAP Diorama_Base.usdz 없음 — 원기둥 받침 사용")
        }

        // 테마 색(결정 58, 서킷 JSON `theme.minimap`): 공원 / 네온 나이트 / 사막 협곡이 미니맵에서도 구분된다. 없으면 기본 팔레트.
        let mm = track.theme?.minimap
        let roadHex = mm?.road ?? StylePalette.mmRoad
        let edgeHex = mm?.edge ?? StylePalette.mmEdge
        let discHex = mm?.disc ?? StylePalette.uiPanel
        let accentHex = mm?.accent ?? StylePalette.uiSky

        // 2. 지형 원판(디자인 PRD 6장 "평평한 원판", 색은 목업대로 ui-panel — 테마가 있으면 테마 색).
        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.004, radius: radius * 0.94),
            materials: [UnlitMaterial(color: .style(discHex))]
        )
        disc.position.y = 0.002
        minimap.mapRoot.addChild(disc)

        // 3. 노면 리본: 테두리(mm-edge) → 노면(mm-road) → 궤적(ui-sky 40 %) 세 층. 트랙 중심선 그대로.
        let roadWidth = projection.mapLength(track.width)
        let layers: [(width: Float, y: Float, material: UnlitMaterial)] = [
            (roadWidth * 1.25, 0.0045, UnlitMaterial(color: .style(edgeHex))),
            (roadWidth, 0.0055, UnlitMaterial(color: .style(roadHex))),
            (roadWidth / 3, 0.0065, trajectoryMaterial()),
        ]
        let mapPoints = path.points.map { projection.mapPosition($0) }
        for layer in layers {
            addRibbon(points: mapPoints, width: layer.width, y: layer.y, material: layer.material, into: minimap.mapRoot)
        }

        // 3b. 서킷(결정 58): 고가 구간(노면 0.8 m 이상 — 다리·루프·헬릭스 윗부분)은 테마 강조색 띠로, 특징 구간(루프·헬릭스·
        //     시케인·뱅크…)은 짧은 라벨로 표시해 어느 구간에서 어떤 스킬이 필요한지 미니맵만 봐도 알 수 있게 한다.
        if let frames = track.frames, frames.count == mapPoints.count {
            let accent = UnlitMaterial(color: .style(accentHex))
            var run: [SIMD2<Float>] = []
            func flush() {
                if run.count >= 2 { addRibbon(points: run, width: roadWidth * 0.45, y: 0.0068, material: accent, into: minimap.mapRoot, closed: false) }
                run.removeAll()
            }
            for (i, frame) in frames.enumerated() {
                if frame.count > 1, frame[1] > 0.8 { run.append(mapPoints[i]) } else { flush() }
            }
            flush()
            let skip: Set<String> = ["직선", "백 스트레이트"]
            for section in track.sections ?? [] where !skip.contains(section.feature) {
                let mid = mapPoints[min((section.from + section.to) / 2, mapPoints.count - 1)]
                let label = makeText(section.feature, size: 0.0052, material: UnlitMaterial(color: .style(accentHex)))
                label.wrapper.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]) // 누워서 위를 보게
                label.wrapper.position = SIMD3(mid.x, 0.0095, mid.y)
                minimap.mapRoot.addChild(label.wrapper)
            }
        }

        // 4. 출발 깃발: 기둥 + 작은 깃발(mm-finish). 체커 무늬는 보류(결정 48).
        if track.start.pathIndex < mapPoints.count {
            let s = mapPoints[track.start.pathIndex]
            let pole = ModelEntity(mesh: .generateBox(size: SIMD3(0.0012, 0.014, 0.0012)), materials: [UnlitMaterial(color: .style(StylePalette.uiInk))])
            pole.position = SIMD3(s.x, 0.007 + 0.006, s.y)
            let flag = ModelEntity(mesh: .generateBox(size: SIMD3(0.007, 0.005, 0.0008)), materials: [UnlitMaterial(color: .style(StylePalette.mmFinish))])
            flag.position = SIMD3(s.x + 0.0041, 0.0175, s.y)
            minimap.mapRoot.addChild(pole)
            minimap.mapRoot.addChild(flag)
        }

        // 5. 체크포인트 라벨: 둥근 디스크 + 숫자. 미통과 ui-ink 40 %, 통과 ui-cyan(`Minimap.update`가 바꾼다).
        var discs: [ModelEntity] = []
        for (ordinal, pathIndex) in track.checkpoints.enumerated() where pathIndex < mapPoints.count {
            let c = mapPoints[pathIndex]
            let label = ModelEntity(mesh: .generateCylinder(height: 0.0012, radius: 0.0065), materials: [UnlitMaterial(color: .style(StylePalette.uiInk))])
            label.position = SIMD3(c.x, 0.0075, c.y)
            let digit = makeText("\(ordinal + 1)", size: 0.007, material: UnlitMaterial(color: .style(StylePalette.uiNight)))
            digit.wrapper.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]) // 누워서 위를 보게
            digit.wrapper.position.y = 0.0007
            label.addChild(digit.wrapper)
            minimap.mapRoot.addChild(label)
            discs.append(label)
        }
        minimap.setCheckpointDiscs(discs)

        // 6. 카트 마커 그림자(ui-cyan 원). 마커 자체는 카트가 로드된 뒤 `setMarker`로 들어온다.
        let shadow = ModelEntity(mesh: .generateCylinder(height: 0.0008, radius: 0.009), materials: [shadowMaterial()])
        shadow.position.y = -0.0005
        minimap.markerSlot.addChild(shadow)

        // 7. 랩 텍스트: 테이블 앞쪽(로컬 +Z) 가장자리에 살짝 기울여.
        let lap = makeText("1 / \(track.laps)", size: 0.012, material: UnlitMaterial(color: .style(StylePalette.uiInk)))
        lap.wrapper.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0, 0])
        lap.wrapper.position = SIMD3(0, 0.006, radius * 0.86)
        minimap.root.addChild(lap.wrapper)
        minimap.setLapText(lap.model)

        return minimap
    }

    // MARK: - 조각들

    /// 점열을 폭 `width`의 납작한 리본 **메시 하나**로 만든다(결정 59, Issue #45): 전에는 구간마다 상자 엔티티 + 이음 정사각을
    /// 따로 만들어 서킷(300~440점 × 3층)에서 엔티티가 2,000개를 넘었다. 지금은 층마다 ModelEntity 1개(삼각형 ≈ 점 수 × 4).
    /// 구간 사각형 + 꺾이는 점의 정사각(틈 메움)을 같은 메시에 넣는다.
    @MainActor
    private static func addRibbon(points: [SIMD2<Float>], width: Float, y: Float, material: UnlitMaterial, into parent: Entity, closed: Bool = true) {
        guard points.count >= 2 else { return }
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let half = width / 2
        func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            let base = UInt32(positions.count)
            positions.append(contentsOf: [a, b, c, d])
            // 위에서 볼 때 반시계(+Y 법선)
            indices.append(contentsOf: [base, base + 2, base + 1, base, base + 3, base + 2])
        }
        let count = closed ? points.count : points.count - 1
        for i in 0..<count {
            let a = points[i], b = points[(i + 1) % points.count]
            let delta = b - a
            let length = simd_length(delta)
            if length > 0.0001 {
                let dir = delta / length
                let side = SIMD2(-dir.y, dir.x) * half
                quad(SIMD3(a.x + side.x, y, a.y + side.y), SIMD3(b.x + side.x, y, b.y + side.y),
                     SIMD3(b.x - side.x, y, b.y - side.y), SIMD3(a.x - side.x, y, a.y - side.y))
            }
            quad(SIMD3(a.x - half, y, a.y - half), SIMD3(a.x - half, y, a.y + half),
                 SIMD3(a.x + half, y, a.y + half), SIMD3(a.x + half, y, a.y - half))
        }
        var descriptor = MeshDescriptor(name: "ribbon")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(Array(repeating: SIMD3<Float>(0, 1, 0), count: positions.count))
        descriptor.primitives = .triangles(indices)
        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            parent.addChild(ModelEntity(mesh: mesh, materials: [material]))
        } catch {
            debugLog("DEBUG-MINIMAP 리본 메시 생성 실패: \(error)")
        }
    }

    private static func trajectoryMaterial() -> UnlitMaterial {
        var m = UnlitMaterial(color: .style(StylePalette.uiSky))
        m.blending = .transparent(opacity: 0.4)
        return m
    }

    private static func shadowMaterial() -> UnlitMaterial {
        var m = UnlitMaterial(color: .style(StylePalette.uiCyan))
        m.blending = .transparent(opacity: 0.6)
        return m
    }

    @MainActor
    private static func recolor(_ entity: Entity, with material: SimpleMaterial) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = Array(repeating: material, count: max(model.materials.count, 1))
            entity.components.set(model)
        }
        for child in entity.children { recolor(child, with: material) }
    }

    static func textMesh(_ text: String, size: CGFloat) -> MeshResource {
        .generateText(text, extrusionDepth: 0.0006, font: .systemFont(ofSize: size, weight: .bold), containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping)
    }

    /// `generateText`는 원점이 글자 왼쪽 아래라, 글자 바운딩 박스 중심이 `wrapper` 원점에 오도록 모델을 안쪽에서 옮긴다.
    /// 회전·배치는 `wrapper`에 건다.
    @MainActor
    static func makeText(_ text: String, size: CGFloat, material: UnlitMaterial) -> (wrapper: Entity, model: ModelEntity) {
        let wrapper = Entity()
        let model = ModelEntity(mesh: textMesh(text, size: size), materials: [material])
        wrapper.addChild(model)
        centerText(model)
        return (wrapper, model)
    }

    /// 모델의 메시 바운딩 박스 중심을 부모 원점에 맞춘다(메시를 바꾼 뒤에도 다시 호출).
    @MainActor
    static func centerText(_ model: ModelEntity) {
        guard let bounds = model.model?.mesh.bounds else { return }
        model.position = SIMD3(-bounds.center.x, -bounds.center.y, 0)
    }
}
#endif
