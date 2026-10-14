import Foundation

/// 단순 자동 조향(결정 58 통합 테스트 → 결정 66 데모 촬영 공용). 중심선에서 벗어나거나 상대 yaw가 크면 되돌리는 쪽으로
/// 한 손 핀치(회전, 가속 없음), 아니면 양손 핀치(전진). 루프·급경사(진행 방향 y가 큰 곳)에서는 핸들을 잡지 않는다(스로틀 유지).
public enum Autopilot {
    public static func drive(state: RailMotionState, spline: TrackSpline) -> DriveState {
        let frame = spline.frame(at: state.s)
        if abs(frame.tangent.y) > 0.35 { return .pedal(1) }
        let desiredYaw = state.lateral * 0.35 // 오른쪽(lateral +)에 있으면 왼쪽(+yaw)으로
        let error = desiredYaw - state.yaw
        if abs(error) > 0.12 { return error > 0 ? .turnLeft : .turnRight }
        return .pedal(1)
    }
}
