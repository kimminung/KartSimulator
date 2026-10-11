import Foundation

/// 3인칭 콕핏(추적 카메라) 배치 튜닝(결정 44~47·49). 전부 미터·초.
public struct CockpitTuning: Sendable {
    /// 3인칭: 사용자 눈(헤드셋)이 카트 노면보다 얼마나 위에 있게 할지(카트를 내려다보는 높이).
    public var thirdPersonEyeAboveFloor: Float
    /// 3인칭: 카트를 기준 방향으로 이만큼 앞에 둔다.
    public var thirdPersonKartAhead: Float
    /// 실제 크기 모드에서 카트의 가장 긴 변 길이(디자인 PRD 4장: 전장 1.5 m).
    public var kartRealLength: Float
    /// 3인칭 추적 카메라: 씬 yaw가 "카트 뒤에서 앞을 보는" 목표 yaw를 따라가는 속도(1/s). 월드가 도는
    /// 것이라 멀미 요인 — 낮을수록 부드럽지만 코너에서 카트가 잠깐 옆을 본다(결정 46).
    public var thirdPersonChaseYawRate: Float
    /// 기준 방향 리센터(Issue #25): 머리가 기준에서 이 각도(도) 이상 벗어난 채 `recenterHoldSeconds` 넘게 머물면
    /// 기준 방향을 머리 쪽으로 `recenterRate`(1/s)로 다시 맞춘다. 그 안쪽(±freeLookDegrees)은 자유롭게 둘러본다.
    public var freeLookDegrees: Float
    public var recenterThresholdDegrees: Float
    public var recenterHoldSeconds: Float
    public var recenterRate: Float

    public init(
        thirdPersonEyeAboveFloor: Float = 1.8,
        thirdPersonKartAhead: Float = 2.5,
        kartRealLength: Float = 1.5,
        thirdPersonChaseYawRate: Float = 2.5,
        freeLookDegrees: Float = 45,
        recenterThresholdDegrees: Float = 60,
        recenterHoldSeconds: Float = 2,
        recenterRate: Float = 1.0
    ) {
        self.thirdPersonEyeAboveFloor = thirdPersonEyeAboveFloor
        self.thirdPersonKartAhead = thirdPersonKartAhead
        self.kartRealLength = kartRealLength
        self.thirdPersonChaseYawRate = thirdPersonChaseYawRate
        self.freeLookDegrees = freeLookDegrees
        self.recenterThresholdDegrees = recenterThresholdDegrees
        self.recenterHoldSeconds = recenterHoldSeconds
        self.recenterRate = recenterRate
    }
}

/// 3인칭 카메라의 **기준 방향**(결정 47·49, Issue #25): 모드에 들어온 순간의 머리 yaw로 고정하고, 이후 머리는
/// 카메라에 쓰지 않는다(고개를 돌려도 카트·세계가 따라오지 않아 양옆을 볼 수 있다). 다만 몸을 돌려 앉은 경우를
/// 위해, 머리가 `recenterThresholdDegrees` 밖에 `recenterHoldSeconds` 넘게 머물면 기준을 머리 쪽으로 천천히 옮긴다.
public struct ChaseCameraReference: Equatable, Sendable {
    /// 현재 기준 yaw(씬 좌표계). `cockpitTarget`·`chaseSceneYaw`의 "바라보는 방향"으로 쓴다.
    public private(set) var forwardYaw: Float
    private var outsideFor: Float = 0
    public private(set) var isRecentering = false

    public init(forwardYaw: Float) {
        self.forwardYaw = forwardYaw
    }

    /// 기준에서 머리가 벗어난 각도(라디안, 부호 있음, ±π).
    public func headOffset(headYaw: Float) -> Float {
        atan2(sin(headYaw - forwardYaw), cos(headYaw - forwardYaw))
    }

    /// 매 프레임 호출. 머리 yaw가 없으면(트래킹 없음) 아무것도 하지 않는다.
    public mutating func update(headYaw: Float?, deltaTime: Float, tuning: CockpitTuning) {
        guard let headYaw else { return }
        let offsetDegrees = abs(headOffset(headYaw: headYaw)) * 180 / .pi
        if isRecentering {
            forwardYaw = ScenePlacement.approachAngle(from: forwardYaw, to: headYaw, rate: tuning.recenterRate, deltaTime: deltaTime)
            // 머리 방향에 거의 맞으면(2° 안) 끝낸다. 이후 다시 60°를 넘겨 2초 머물 때까지 고정.
            if offsetDegrees <= 2 { isRecentering = false; outsideFor = 0 }
            return
        }
        if offsetDegrees > tuning.recenterThresholdDegrees {
            outsideFor += deltaTime
            if outsideFor >= tuning.recenterHoldSeconds { isRecentering = true }
        } else {
            outsideFor = 0
        }
    }
}

/// 트랙 좌표계(미터, 노면 y = 0)에 놓인 씬 루트를 월드에 배치하는 수학. 씬 루트 변환은
/// `world = position + scale · R_y(yaw) · local` 하나뿐이다(회전은 Y축만).
///
/// - 디오라마: `scale` = 박스 맞춤 배율, `yaw` = π(결정 43), `position`은 트랙 중심이 박스 바닥 중앙에 오게.
/// - 3인칭: `scale` = 1, `yaw`는 매 프레임 "카트 heading이 기준 방향을 향하게"로 평활 회전(결정 46),
///   `position`은 "카트 트랙 좌표가 콕핏 목표점에 오게"(결정 44·47).
public enum ScenePlacement {
    /// `KartMotionState`와 같은 정면 벡터: heading h → (-sin h, 0, -cos h).
    public static func forward(heading: Float) -> SIMD3<Float> {
        SIMD3(-sin(heading), 0, -cos(heading))
    }

    /// Y축 회전 R_y(yaw)·v. `KartForwardCorrection`과 같은 부호 관례(RealityKit `simd_quatf(angle:axis:[0,1,0])`).
    public static func rotateY(_ v: SIMD3<Float>, by yaw: Float) -> SIMD3<Float> {
        let c = cos(yaw), s = sin(yaw)
        return SIMD3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
    }

    /// `local`(트랙 좌표)이 월드 `target`에 놓이도록 하는 씬 루트 position.
    public static func rootPosition(placing local: SIMD3<Float>, at target: SIMD3<Float>, yaw: Float, scale: Float) -> SIMD3<Float> {
        target - rotateY(local, by: yaw) * scale
    }

    /// 모드에 들어온 순간의 씬 yaw: 트랙 출발 heading이 사용자 머리 yaw(씬 좌표계, 같은 공식)를 향하게.
    /// R_y(yaw)·forward(h) = forward(h + yaw) 이므로 h_start + yaw = headYaw.
    public static func sceneYaw(startHeading: Float, headYaw: Float) -> Float {
        headYaw - startHeading
    }

    /// 3인칭 추적 카메라 목표 yaw: **지금** 카트 heading이 기준 방향(`referenceYaw`, 모드 진입 순간 머리 yaw)을
    /// 향하게(= 카트 뒤에서 앞을 본다). 호출자가 `approachAngle`로 평활해서 씬 yaw에 반영한다(결정 46·49).
    public static func chaseSceneYaw(kartHeading: Float, referenceYaw: Float) -> Float {
        referenceYaw - kartHeading
    }

    /// 콕핏 목표점: 카트(트랙 좌표 노면 위 원점)가 월드에서 와야 할 자리. `anchor`는 모드 진입 순간의 머리 위치(월드).
    /// 3인칭: 거기서 `thirdPersonEyeAboveFloor` 아래, **기준 방향 `referenceYaw`**(모드 진입 순간 머리 yaw, 리센터
    /// 전까지 고정 — `ChaseCameraReference`)으로 `thirdPersonKartAhead`만큼 앞. 고개를 돌려도 카트는 그 자리에 있다(Issue #25).
    public static func cockpitTarget(
        anchor: SIMD3<Float>,
        mode: ExperienceMode,
        referenceYaw: Float,
        tuning: CockpitTuning
    ) -> SIMD3<Float> {
        switch mode {
        case .diorama:
            return anchor
        case .thirdPerson:
            let ahead = forward(heading: referenceYaw) * tuning.thirdPersonKartAhead
            return anchor - SIMD3(0, tuning.thirdPersonEyeAboveFloor, 0) + ahead
        }
    }

    /// 각도를 `target` 쪽으로 최단 경로(±π 랩어라운드)로 지수 평활한다. `rate`(1/s)가 클수록 빨리 따라간다.
    /// 3인칭에서 머리 yaw의 떨림이 카트 위치로 그대로 전달되지 않게 하는 용도.
    public static func approachAngle(from current: Float, to target: Float, rate: Float, deltaTime: Float) -> Float {
        let delta = atan2(sin(target - current), cos(target - current))
        let alpha = 1 - exp(-max(rate, 0) * max(deltaTime, 0))
        return current + delta * alpha
    }

    /// 카트 모델의 가장 긴 변을 트랙 좌표계에서 몇 m로 맞출지. 디오라마는 박스 배율과 무관하게
    /// 눈에 보이는 고정 크기(`visualLength`), 실제 크기 모드는 실제 전장.
    public static func kartFitLength(mode: ExperienceMode, sceneScale: Float, dioramaVisualLength: Float, tuning: CockpitTuning) -> Float {
        switch mode {
        case .diorama: return dioramaVisualLength / max(sceneScale, 0.0001)
        case .thirdPerson: return tuning.kartRealLength
        }
    }
}
