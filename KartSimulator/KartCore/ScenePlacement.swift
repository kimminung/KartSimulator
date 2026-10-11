import Foundation

/// 1인칭·3인칭 콕핏 배치 튜닝(결정 44, Phase 2). 전부 미터.
public struct CockpitTuning: Sendable {
    /// 1인칭: 사용자 눈(헤드셋)이 카트 바닥(트랙 노면)보다 얼마나 위에 있게 할지. 앉은 카트 드라이버 눈높이.
    public var firstPersonEyeAboveFloor: Float
    /// 3인칭: 같은 값. 카트를 내려다보도록 더 높다.
    public var thirdPersonEyeAboveFloor: Float
    /// 3인칭: 카트를 사용자보다 카트 진행 방향으로 이만큼 앞에 둔다(0이면 1인칭과 같은 자리).
    public var thirdPersonKartAhead: Float
    /// 실제 크기 모드에서 카트의 가장 긴 변 길이(디자인 PRD 4장: 전장 1.5 m).
    public var kartRealLength: Float

    public init(
        firstPersonEyeAboveFloor: Float = 0.9,
        thirdPersonEyeAboveFloor: Float = 1.8,
        thirdPersonKartAhead: Float = 2.5,
        kartRealLength: Float = 1.5
    ) {
        self.firstPersonEyeAboveFloor = firstPersonEyeAboveFloor
        self.thirdPersonEyeAboveFloor = thirdPersonEyeAboveFloor
        self.thirdPersonKartAhead = thirdPersonKartAhead
        self.kartRealLength = kartRealLength
    }
}

/// 트랙 좌표계(미터, 노면 y = 0)에 놓인 씬 루트를 월드에 배치하는 수학. 씬 루트 변환은
/// `world = position + scale · R_y(yaw) · local` 하나뿐이다(회전은 Y축만).
///
/// - 디오라마: `scale` = 박스 맞춤 배율, `yaw` = π(결정 43), `position`은 트랙 중심이 박스 바닥 중앙에 오게.
/// - 1인칭·3인칭: `scale` = 1, `yaw`는 모드에 들어온 순간 "출발 heading이 사용자 머리 방향을 향하게",
///   `position`은 매 프레임 "카트 트랙 좌표가 콕핏 목표점에 오게"(월드는 평행이동만 하고 돌지 않는다 — 결정 44).
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

    /// 콕핏 목표점: 카트(트랙 좌표 노면 위 원점)가 월드에서 와야 할 자리.
    /// `anchor`는 사용자 머리 위치(월드). 1인칭은 머리 바로 아래 눈높이만큼 내려간 곳,
    /// 3인칭은 거기서 더 낮추고 카트 진행 방향(월드 기준 = heading + sceneYaw)으로 `thirdPersonKartAhead`만큼 앞.
    public static func cockpitTarget(
        anchor: SIMD3<Float>,
        mode: ExperienceMode,
        kartHeading: Float,
        sceneYaw: Float,
        tuning: CockpitTuning
    ) -> SIMD3<Float> {
        switch mode {
        case .diorama:
            return anchor
        case .firstPerson:
            return anchor - SIMD3(0, tuning.firstPersonEyeAboveFloor, 0)
        case .thirdPerson:
            let ahead = forward(heading: kartHeading + sceneYaw) * tuning.thirdPersonKartAhead
            return anchor - SIMD3(0, tuning.thirdPersonEyeAboveFloor, 0) + ahead
        }
    }

    /// 카트 모델의 가장 긴 변을 트랙 좌표계에서 몇 m로 맞출지. 디오라마는 박스 배율과 무관하게
    /// 눈에 보이는 고정 크기(`visualLength`), 실제 크기 모드는 실제 전장.
    public static func kartFitLength(mode: ExperienceMode, sceneScale: Float, dioramaVisualLength: Float, tuning: CockpitTuning) -> Float {
        switch mode {
        case .diorama: return dioramaVisualLength / max(sceneScale, 0.0001)
        case .firstPerson, .thirdPerson: return tuning.kartRealLength
        }
    }
}
