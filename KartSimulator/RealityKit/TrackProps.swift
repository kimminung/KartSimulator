#if os(visionOS) || os(iOS)
import Foundation
import RealityKit

/// 트랙 소품(결정 65, Issue #61): 승인 풍차 `windmill.usdz`(목재) / `windmill_small.usdz`(흰·녹색)를 루키 오벌(공원) 외곽에 두고,
/// 원본 Molang 각속도대로 `sails` Z축 +36°/초(10초), `fantail` X축 −50°/초(7.2초)를 런타임에 누적 회전시킨다.
/// 모델은 미터(1/16) 단위로 변환했고 원본 client entity의 `scale: 2`는 여기서 엔티티 배율로 적용한다.
@MainActor
final class TrackProps {
    struct Placement {
        let model: String
        let position: SIMD3<Float>
        let yawDegrees: Float
        let scale: Float
    }

    /// 트랙별 소품 배치(트랙 좌표, m). 루키 오벌: 바운딩 박스 x −18..0, z −45..9 바깥, 중심선에서 12 m 이상 떨어진 잔디.
    /// 모델은 1/16 m 기준 15.4 m 높이라 원본 `scale: 2`(30 m)는 트랙(50 m)에 비해 너무 커서(시뮬레이터 확인: 날개가 노면 위를
    /// 덮음) **0.6배(≈ 9 m)**로 "작은 풍경 소품"(디자인 README 제안)으로 둔다. 원본 2배는 굽지 않았으므로 여기서만 바꾸면 된다.
    static func placements(for trackID: String) -> [Placement] {
        switch trackID {
        case "circuit_01":
            // 잔디 바닥판은 바운딩 박스 + 6 m까지만 있으므로 그 안쪽(5 m)에 둔다 — 탑뷰 카메라 프레임에도 들어온다.
            return [
                Placement(model: "windmill", position: SIMD3(-22, 0, -12), yawDegrees: 30, scale: 0.6),
                Placement(model: "windmill_small", position: SIMD3(4, 0, -40), yawDegrees: -120, scale: 0.6),
            ]
        default:
            return []
        }
    }

    private struct Spinner {
        let entity: Entity
        let axis: SIMD3<Float>
        let degreesPerSecond: Float
        let base: simd_quatf
        var angle: Float = 0
    }

    private var spinners: [Spinner] = []
    private var templates: [String: Entity] = [:]

    /// 소품을 `parent`(씬 루트) 아래에 만든다. 모델을 못 읽으면 조용히 건너뛴다.
    func build(for trackID: String, into parent: Entity) async {
        spinners.removeAll()
        for placement in Self.placements(for: trackID) {
            guard let template = await template(named: placement.model) else { continue }
            let entity = template.clone(recursive: true)
            entity.name = placement.model
            entity.position = placement.position
            entity.scale = SIMD3(repeating: placement.scale)
            entity.orientation = simd_quatf(angle: placement.yawDegrees * .pi / 180, axis: [0, 1, 0])
            parent.addChild(entity)
            if let sails = entity.findEntity(named: "sails") {
                spinners.append(Spinner(entity: sails, axis: [0, 0, 1], degreesPerSecond: 36, base: sails.orientation))
            }
            if let fantail = entity.findEntity(named: "fantail") {
                spinners.append(Spinner(entity: fantail, axis: [1, 0, 0], degreesPerSecond: -50, base: fantail.orientation))
            }
        }
        debugLog("DEBUG-PROPS \(trackID): 소품 \(Self.placements(for: trackID).count)개, 회전 노드 \(spinners.count)개")
    }

    /// 매 프레임: 누적 각도로 회전(두 쿼터니언 키프레임 대신 연속 회전 — 원본 README의 주의대로).
    func update(deltaTime: Float) {
        guard deltaTime > 0 else { return }
        for i in spinners.indices {
            spinners[i].angle += spinners[i].degreesPerSecond * .pi / 180 * deltaTime
            if abs(spinners[i].angle) > 2 * .pi { spinners[i].angle -= copysign(2 * .pi, spinners[i].angle) }
            spinners[i].entity.orientation = spinners[i].base * simd_quatf(angle: spinners[i].angle, axis: spinners[i].axis)
        }
    }

    private func template(named name: String) async -> Entity? {
        if let cached = templates[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            debugLog("DEBUG-PROPS \(name).usdz 없음")
            return nil
        }
        do {
            let entity = try await Entity(contentsOf: url)
            templates[name] = entity
            return entity
        } catch {
            debugLog("DEBUG-PROPS \(name) 로드 실패: \(error)")
            return nil
        }
    }
}

/// 운전자(결정 64·65, Issue #63): 승인 `driver_01`의 `kart_idle` **착석 자세**(첫 프레임)를 정적으로 구운 USDZ를 **카트 엔티티의 자식**으로
/// 붙인다(클립 재생은 후속 — Blender USD 변환의 시간 샘플이 RealityKit 애니메이션으로 잡히지 않았다). 자세에 좌석 이동이 들어 있으므로
/// 위치는 카트 원점(0)이고, 배율은 카트 모델의 원래 크기 ÷ 설계 전장 1.5 m — 카트가 Bedrock 16유닛 = 1 m 기준보다 크게 변환돼
/// 있어도(가스펠 USDZ 전장 ≈ 3.3 m) 운전자가 같은 비율로 커져 카트 배율을 한 번만 받는다. RetireX 비례대로 운전자가 카트보다 크다.
enum DriverRig {
    static let fittedKarts: Set<String> = ["gospel"] // `Design/karts/seats.md`: 가스펠만 피팅 확인, 나머지 4종은 미정
    /// 사용자 지시(2026-10-14): Bedrock 원비례(운전자가 카트보다 큼)보다 **카트 비례에 맞게 줄인다**. 1.0 = 원비례.
    static let proportionFactor: Float = 0.65

    @MainActor
    static func attach(to kart: Entity, kartID: String, designLength: Float = 1.5) async {
        guard fittedKarts.contains(kartID) else { return }
        guard let url = Bundle.main.url(forResource: "driver_01", withExtension: "usdz") else {
            debugLog("DEBUG-DRIVER driver_01.usdz 없음")
            return
        }
        do {
            let driver = try await Entity(contentsOf: url)
            driver.name = "driver_01"
            let bounds = kart.visualBounds(relativeTo: kart)
            let native = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let unitScale = (native > 0 ? native / designLength : 1) * proportionFactor
            driver.scale = SIMD3(repeating: unitScale)
            driver.position = .zero
            // 카트 USDZ는 Bedrock 원본과 달리 +Z가 앞(정면 보정 180°, 결정 42)이라, Bedrock 좌표로 피팅된 운전자(−Z 앞, 좌석 +0.125 z)는
            // 카트 로컬에서 Y축 180° 돌려 붙여야 앞을 보고 좌석에 앉는다(시뮬레이터 확인: 돌리기 전엔 카메라를 마주 봤다).
            driver.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            kart.addChild(driver)
            let names = driver.availableAnimations.map { $0.name ?? "?" }
            if let clip = driver.availableAnimations.first {
                driver.playAnimation(clip.repeat(), transitionDuration: 0, startsPaused: false)
            }
            debugLog("DEBUG-DRIVER 부착 kart=\(kartID) 배율=\(unitScale) 클립=\(names)")
        } catch {
            debugLog("DEBUG-DRIVER 로드 실패: \(error)")
        }
    }
}
#endif
