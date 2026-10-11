import Foundation

/// 디오라마/3인칭 모드는 양손 핀치 조합으로 전·후진과 회전을 같은 값에 담아 표현한다
/// (손이 가속과 조향을 동시에 맡음). 1인칭은 조향이 머리 방향(헤드 포즈)으로 따로 들어와서
/// 손은 가속 여부만 맡는다 — 그래서 `.headSteered`는 조향 값을 담지 않고,
/// `KartMotionState.advancing(drive:desiredHeading:...)`의 별도 파라미터로 받는다(결정 39).
public enum DriveState: Equatable, Sendable {
    case stopped
    /// 디오라마 전용: 양손 핀치했지만 거리를 아직 계산할 수 없는 과도기.
    case waiting
    case turnLeft
    case turnRight
    /// 디오라마: 양손 핀치 시작 지점 대비 상대 거리 기반 "페달". -1(최대 후진)~0~+1(최대 전진).
    /// 3인칭: 항상 `pedal(1.0)`만 나온다(후진 없음) — `HandInputResolver`가 보장한다.
    case pedal(Float)
    /// 1인칭 전용: 한쪽이라도 핀치 중이면 가속. 조향은 머리 방향을 따로 받는다.
    case headSteered(accelerating: Bool)
}
