#if os(visionOS) || os(iOS)
import RealityKit
import simd

/// 로드된 카트 USDZ 안의 움직이는 부품(핸들·차체·바퀴)을 찾아 `KartRigPose`를 적용한다(Issue #26, 결정 51).
///
/// USDZ 5종에 실제로 남아 있는 노드: `steering_wheel`(arcrix·bogubkart·gospel) 또는 `steering_column`(razr·sirius),
/// `root`(차체 기울기 기준). 바퀴 피벗 `A`~`D`는 glb→USDZ 변환에서 이름이 사라져 **지금은 없다** — 재내보내기가
/// 오면 `wheelNames`로 잡힌다(없으면 굴림·앞바퀴 조향은 조용히 건너뛴다).
///
/// 축: 이 로스터는 모델 정면이 로컬 +Z라, 핸들은 자기 로컬 Z축(조향 칼럼 축에 가까움), 차체 roll은 Z축, pitch는 X축,
/// 바퀴 굴림은 X축으로 돌린다. 실기기에서 축이 어긋나 보이면 `axisFix` 상수만 바꾼다.
@MainActor
final class KartRig {
    private struct Part {
        let entity: Entity
        let baseOrientation: simd_quatf
    }

    private var steering: Part?
    private var body: Part?
    private var frontWheels: [Part] = []
    private var rearWheels: [Part] = []
    private(set) var wheelRadius: Float = 0.12
    private(set) var pose = KartRigPose()
    var tuning = KartRigTuning()

    private static let steeringNames = ["steering_wheel", "steering_column"]
    private static let bodyNames = ["root"]
    private static let frontWheelNames = ["a", "c"]
    private static let rearWheelNames = ["b", "d"]

    init(kart: Entity) {
        steering = Self.first(in: kart, named: Self.steeringNames).map { Part(entity: $0, baseOrientation: $0.orientation) }
        body = Self.first(in: kart, named: Self.bodyNames).map { Part(entity: $0, baseOrientation: $0.orientation) }
        frontWheels = Self.frontWheelNames.compactMap { Self.first(in: kart, named: [$0]) }.map { Part(entity: $0, baseOrientation: $0.orientation) }
        rearWheels = Self.rearWheelNames.compactMap { Self.first(in: kart, named: [$0]) }.map { Part(entity: $0, baseOrientation: $0.orientation) }
        if let wheel = (frontWheels + rearWheels).first {
            let bounds = wheel.entity.visualBounds(relativeTo: kart)
            wheelRadius = max(bounds.extents.y / 2, 0.01)
        }
        debugLog("DEBUG-RIG steering=\(steering?.entity.name ?? "없음") body=\(body?.entity.name ?? "없음") frontWheels=\(frontWheels.count) rearWheels=\(rearWheels.count) r=\(wheelRadius)")
    }

    /// 매 프레임. `speed`·`acceleration`은 트랙 단위(m/s, m/s²), `maxSpeed`는 튜닝 최고 속도.
    func update(drive: DriveState, speed: Float, maxSpeed: Float, acceleration: Float, deltaTime: Float) {
        pose.update(drive: drive, speed: speed, maxSpeed: maxSpeed, acceleration: acceleration, wheelRadius: wheelRadius, deltaTime: deltaTime, tuning: tuning)

        if let steering {
            // RetireX: −steering × 82°. 왼손 핀치(steer +) → 핸들이 왼쪽(반시계)으로.
            let angle = -pose.steeringWheelAngle(tuning: tuning) * .pi / 180
            steering.entity.orientation = steering.baseOrientation * simd_quatf(angle: angle, axis: [0, 0, 1])
        }
        if let body {
            let roll = simd_quatf(angle: pose.roll * .pi / 180, axis: [0, 0, 1])
            let pitch = simd_quatf(angle: pose.pitch * .pi / 180, axis: [1, 0, 0])
            body.entity.orientation = body.baseOrientation * roll * pitch
        }
        let spin = simd_quatf(angle: pose.wheelSpin * .pi / 180, axis: [1, 0, 0])
        let steerQuat = simd_quatf(angle: pose.frontWheelAngle(tuning: tuning) * .pi / 180, axis: [0, 1, 0])
        for wheel in frontWheels { wheel.entity.orientation = wheel.baseOrientation * steerQuat * spin }
        for wheel in rearWheels { wheel.entity.orientation = wheel.baseOrientation * spin }
    }

    private static func first(in entity: Entity, named names: [String]) -> Entity? {
        for name in names {
            if let found = find(in: entity, exactly: name) { return found }
        }
        return nil
    }

    private static func find(in entity: Entity, exactly name: String) -> Entity? {
        if entity.name.lowercased() == name { return entity }
        for child in entity.children {
            if let found = find(in: child, exactly: name) { return found }
        }
        return nil
    }
}
#endif
