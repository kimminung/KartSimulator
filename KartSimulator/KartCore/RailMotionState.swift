import Foundation
import simd

/// 카트의 월드 자세(렌더·카메라·미니맵이 읽는다).
public struct KartPose: Equatable, Sendable {
    /// 트랙 좌표(m). 노면 위 카트 원점.
    public var position: SIMD3<Float>
    /// 카트 정면(단위). 루프 안에서는 위·아래를 향할 수 있다.
    public var forward: SIMD3<Float>
    /// 카트 위쪽(단위) = 노면 법선. 루프 꼭대기에서는 −Y.
    public var up: SIMD3<Float>
    /// 평면 heading(라디안, `KartMotionState`와 같은 공식 h = atan2(−fx, −fz)). 정면이 거의 수직이면(루프 안)
    /// 마지막 유효값을 유지한다 — 3인칭 추적 카메라가 이 값을 쓰므로 루프를 통과해도 세계가 돌지 않는다(결정 58).
    public var heading: Float

    public init(position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>, heading: Float) {
        self.position = position
        self.forward = forward
        self.up = up
        self.heading = heading
    }

    /// 정면·위 벡터로 만든 회전(모델 정면 −Z, 위 +Y 기준).
    public var orientation: simd_quatf {
        let f = simd_normalize(forward)
        var u = up - f * simd_dot(up, f)
        if simd_length_squared(u) < 1e-6 { u = SIMD3(0, 1, 0) } else { u = simd_normalize(u) }
        let r = simd_cross(f, u)
        // 열 = 로컬 축의 월드 표현: 로컬 +X → right, +Y → up, +Z → −forward
        let m = simd_float3x3(columns: (r, u, -f))
        return simd_quatf(m)
    }
}

/// 중심선 위를 달리는 **레일 주행 모델**(결정 58). 상태는 호 길이 `s`, 가로 오프셋 `lateral`(오른쪽 +), 트랙 진행 방향에
/// 대한 상대 yaw `yaw`(좌회전 +), 부호 있는 속도 `speed`. 가감속·회전 규칙은 `KartMotionState`와 같고, 거기에
/// - 트랙 곡률: 트랙이 도는 만큼 상대 yaw가 반대로 쌓인다 → 핸들을 안 꺾으면 바깥 벽으로 밀려난다(코너는 여전히 조작 대상)
/// - 안쪽 라인: 중심선 진행량 = 전진량 / (1 + lateral·곡률) — 코너 안쪽을 타면 더 빨리 돈다
/// - 중력: 진행 방향의 y 성분에 비례해 감속/가속(`gravity`). 루프·언덕에서 스로틀을 놓거나 한 손 회전(가속 없음)이면 뒤로 미끄러진다
/// - 벽: |lateral| > `wallHalfWidth`면 멈춰 세우고 속도 일부를 깎는다(`wallSpeedKeep`), 상대 yaw는 벽과 나란해지도록 줄인다
public struct RailMotionState: Equatable, Sendable {
    public var s: Float
    public var lateral: Float
    public var yaw: Float
    public var speed: Float
    /// 마지막 유효 평면 heading(루프 안에서 유지).
    public var heading: Float

    public init(s: Float = 0, lateral: Float = 0, yaw: Float = 0, speed: Float = 0, heading: Float = 0) {
        self.s = s
        self.lateral = lateral
        self.yaw = yaw
        self.speed = speed
        self.heading = heading
    }

    /// 출발 자세: 출발 프레임 위, 중앙, 트랙 방향.
    public init(startOn spline: TrackSpline, frameIndex: Int, speed: Float = 0) {
        let s0 = spline.arcLength(ofFrame: frameIndex)
        let f = spline.frame(at: s0)
        self.init(s: s0, lateral: 0, yaw: 0, speed: speed, heading: atan2(-f.tangent.x, -f.tangent.z))
    }

    public struct Step: Equatable, Sendable {
        public var state: RailMotionState
        public var hitWall: Bool
    }

    public func advancing(drive: DriveState, tuning: MotionTuning, spline: TrackSpline, deltaTime: Float) -> Step {
        var next = self
        guard deltaTime > 0 else { return Step(state: next, hitWall: false) }

        // 1. 가감속(`KartMotionState`와 동일 규칙)
        let target = KartMotionState.targetSpeed(for: drive, current: speed, tuning: tuning)
        let rate = target > speed ? tuning.accel : KartMotionState.decelRate(for: drive, tuning: tuning)
        next.speed = KartMotionState.approach(speed, toward: target, by: rate * deltaTime)

        // 2. 중력: 오르막(진행 방향 y > 0)이면 감속, 내리막이면 가속. 내리막 보너스는 최고 속도의 `downhillSpeedCap`배까지.
        // 중력의 접선 성분은 속도 부호와 무관하다: 오르막(tangent.y > 0)에서는 전진이 느려지고 후진(음수 속도)은 더 빨라진다.
        let here = spline.frame(at: s)
        next.speed -= tuning.gravity * here.tangent.y * deltaTime
        let cap = tuning.maxSpeed * tuning.downhillSpeedCap
        next.speed = min(max(next.speed, -tuning.maxSpeed * tuning.reverseSpeedFactor), cap)

        // 3. 조향(속도 크기 기준, 좌회전 +)
        if (drive == .turnLeft || drive == .turnRight), abs(next.speed) >= tuning.minTurnSpeed || next.speed == 0 {
            let t = min(max(abs(next.speed) / tuning.maxSpeed, 0), 1)
            let turnRateDegrees = tuning.turnRateLow + (tuning.turnRateHigh - tuning.turnRateLow) * t
            let sign: Float = drive == .turnLeft ? 1 : -1
            next.yaw += sign * turnRateDegrees * (.pi / 180) * deltaTime
        }

        // 4. 전진량을 중심선 진행(안쪽 라인 보정)과 가로 이동으로 나눈다
        let advance = next.speed * deltaTime
        let laneFactor = min(max(1 + lateral * here.yawCurvature, 0.5), 2.0)
        let ds = advance * cos(next.yaw) / laneFactor
        next.lateral -= advance * sin(next.yaw) // 왼쪽(+yaw)으로 가면 lateral(오른쪽 +)이 줄어든다
        next.s = spline.wrapped(s + ds)

        // 5. 트랙 곡률만큼 상대 yaw가 반대로 쌓인다(절대 방향 유지)
        next.yaw -= here.yawCurvature * ds
        next.yaw = atan2(sin(next.yaw), cos(next.yaw))

        // 6. 벽: 첫 접촉에서만 속도를 깎고(`wallSpeedKeep`) 그 뒤로는 벽을 따라 미끄러진다 — 상대 yaw를 벽과 나란하게 줄이고
        //    긁는 동안 `coastDecel`만큼 추가로 느려진다(바깥 벽 타기는 되지만 손해).
        var hitWall = false
        if abs(next.lateral) > tuning.wallHalfWidth {
            let wasFree = abs(lateral) < tuning.wallHalfWidth - 1e-3
            next.lateral = next.lateral > 0 ? tuning.wallHalfWidth : -tuning.wallHalfWidth
            let intoWall = (next.lateral > 0 && next.yaw < 0) || (next.lateral < 0 && next.yaw > 0)
            if intoWall {
                if wasFree || abs(next.yaw) > 0.6 {
                    hitWall = true
                    next.speed *= tuning.wallSpeedKeep
                }
                next.yaw *= 0.3
                next.speed = KartMotionState.approach(next.speed, toward: 0, by: tuning.coastDecel * deltaTime)
            }
        }

        // 7. 평면 heading(루프 안에서는 유지)
        let pose = next.pose(on: spline)
        let horizontal = SIMD2(pose.forward.x, pose.forward.z)
        if simd_length(horizontal) > 0.5 {
            next.heading = atan2(-pose.forward.x, -pose.forward.z)
        }
        return Step(state: next, hitWall: hitWall)
    }

    /// 현재 상태의 월드 자세.
    public func pose(on spline: TrackSpline) -> KartPose {
        let f = spline.frame(at: s)
        let right = f.right
        let position = f.position + right * lateral
        // 상대 yaw만큼 노면 법선 둘레로 돌린 정면: 좌회전(+)이면 tangent에서 −right 쪽으로
        let forward = simd_normalize(f.tangent * cos(yaw) - right * sin(yaw))
        let horizontal = SIMD2(forward.x, forward.z)
        let h = simd_length(horizontal) > 0.5 ? atan2(-forward.x, -forward.z) : heading
        return KartPose(position: position, forward: forward, up: f.up, heading: h)
    }
}
