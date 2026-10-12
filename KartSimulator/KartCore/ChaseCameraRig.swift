import Foundation
import simd

/// iOS/iPadOS 가상 카메라 수학(결정 60, Issue #50). visionOS는 세계를 움직이지만(`ScenePlacement`) 화면 기기는 카메라를 움직인다.
/// 두 모드: **탑뷰**(트랙 전체가 화면에 들어오게 위에서 내려다봄 — 디오라마에 해당)와 **추적**(카트 뒤 2.5 m·위 1.8 m에서
/// 카트가 가는 쪽을 봄 — 3인칭에 해당). 추적 yaw는 `KartPose.heading`을 쓰므로 루프 안에서도 카메라가 뒤집히지 않는다.
public enum CameraViewMode: String, CaseIterable, Sendable {
    case topView
    case chase
    /// iPad/iPhone AR(Issue #51, 선택): 기기 카메라 영상 위 수평면에 디오라마 배율로 올린다. 시뮬레이터에서는 쓸 수 없다.
    case ar
}

public struct CameraPose: Equatable, Sendable {
    public var position: SIMD3<Float>
    public var target: SIMD3<Float>
    public var up: SIMD3<Float>

    public init(position: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float> = SIMD3(0, 1, 0)) {
        self.position = position
        self.target = target
        self.up = up
    }
}

public struct ChaseCameraTuning: Equatable, Sendable {
    public var behind: Float
    public var above: Float
    public var lookAhead: Float
    /// 위치 평활(1/s). 클수록 바짝 따라간다.
    public var followRate: Float
    public var fieldOfViewDegrees: Float
    /// 탑뷰: 트랙 바운딩 박스 바깥 여백 배율.
    public var topViewMargin: Float
    /// 탑뷰: 수직에서 살짝 기울여 입체감을 준다(도).
    public var topViewTiltDegrees: Float

    public init(behind: Float = 2.5, above: Float = 1.8, lookAhead: Float = 2.0, followRate: Float = 6, fieldOfViewDegrees: Float = 60, topViewMargin: Float = 1.35, topViewTiltDegrees: Float = 20) {
        self.behind = behind
        self.above = above
        self.lookAhead = lookAhead
        self.followRate = followRate
        self.fieldOfViewDegrees = fieldOfViewDegrees
        self.topViewMargin = topViewMargin
        self.topViewTiltDegrees = topViewTiltDegrees
    }
}

public enum ChaseCameraRig {
    /// 추적 카메라 목표 자세: 카트 평면 heading 기준 뒤·위, 카트 조금 앞을 본다. 루프에서는 카트 높이를 따라 오르내린다.
    public static func chaseTarget(pose: KartPose, tuning: ChaseCameraTuning) -> CameraPose {
        let forward = ScenePlacement.forward(heading: pose.heading)
        let position = pose.position - forward * tuning.behind + SIMD3(0, tuning.above, 0)
        let target = pose.position + forward * tuning.lookAhead + SIMD3(0, 0.3, 0)
        return CameraPose(position: position, target: target)
    }

    /// 탑뷰: 트랙 평면 바운딩 박스(xz)가 세로 FOV 안에 들어오는 높이에서 중심을 내려다본다. 화면 종횡비(`aspect` = 가로/세로)에 맞춰
    /// 가로 폭도 들어오게 한다.
    public static func topView(minXZ: SIMD2<Float>, maxXZ: SIMD2<Float>, maxHeight: Float, aspect: Float, tuning: ChaseCameraTuning) -> CameraPose {
        let center = (minXZ + maxXZ) / 2
        let span = maxXZ - minXZ
        let halfFov = tuning.fieldOfViewDegrees / 2 * .pi / 180
        let tanHalf = tan(halfFov)
        // 세로 FOV로 z 폭, 가로 FOV(= 세로 × aspect)로 x 폭을 덮는 높이 중 큰 쪽
        let heightForZ = (span.y / 2) / tanHalf
        let heightForX = (span.x / 2) / (tanHalf * max(aspect, 0.1))
        let height = max(heightForZ, heightForX, 5) * tuning.topViewMargin + maxHeight
        let tilt = tuning.topViewTiltDegrees * .pi / 180
        // 남쪽(+z)으로 살짝 물러나 기울인다 — 출발 직선이 화면 아래에서 위로 뻗어 보이게.
        let position = SIMD3(center.x, height * cos(tilt), center.y + height * sin(tilt))
        return CameraPose(position: position, target: SIMD3(center.x, 0, center.y), up: SIMD3(0, 0, -1))
    }

    /// 지수 평활로 현재 카메라를 목표에 붙인다.
    public static func follow(current: CameraPose, target: CameraPose, rate: Float, deltaTime: Float) -> CameraPose {
        let alpha = 1 - exp(-max(rate, 0) * max(deltaTime, 0))
        return CameraPose(
            position: current.position + (target.position - current.position) * alpha,
            target: current.target + (target.target - current.target) * alpha,
            up: target.up
        )
    }
}
