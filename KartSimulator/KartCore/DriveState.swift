import Foundation

public enum DriveState: Equatable, Sendable {
    case stopped
    case waiting
    case turnLeft
    case turnRight
    /// 양손 핀치 거리 기반 "페달" 입력. -1(최대 후진)~0(중립)~+1(최대 전진).
    /// `HandInputResolver.pedalValue(for:)`가 계산한다.
    case pedal(Float)
}
