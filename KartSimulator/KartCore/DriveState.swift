import Foundation

public enum DriveState: Equatable, Sendable {
    case stopped
    case waiting
    case forwardHalf
    case forwardFull
    case turnLeft
    case turnRight
}
