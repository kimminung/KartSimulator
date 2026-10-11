import Foundation

/// 양손 핀치 조합으로 전·후진과 회전을 같은 값에 담아 표현한다(손이 가속과 조향을 동시에 맡음).
/// 디오라마·3인칭 두 모드가 같은 규칙을 쓴다(결정 49). 1인칭의 `.headSteered`는 결정 47·49로 폐기됐다.
public enum DriveState: Equatable, Sendable {
    case stopped
    /// 양손 핀치했지만 거리를 아직 계산할 수 없는 과도기.
    case waiting
    case turnLeft
    case turnRight
    /// 양손 핀치 시작 지점 대비 상대 거리 기반 "페달". -1(최대 후진)~0~+1(최대 전진).
    case pedal(Float)
}
