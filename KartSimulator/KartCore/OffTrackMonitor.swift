import Foundation

/// 트랙 밖 체류 시간을 누적해 리스폰 시점을 알려준다 (테크 PRD 6장 "트랙 이탈 복귀").
public final class OffTrackMonitor {
    private var elapsed: TimeInterval = 0
    public private(set) var shouldRespawn = false

    public func update(isOffTrack: Bool, deltaTime: TimeInterval, threshold: TimeInterval) {
        guard !shouldRespawn else { return }
        if isOffTrack {
            elapsed += deltaTime
            shouldRespawn = elapsed >= threshold
        } else {
            elapsed = 0
        }
    }

    public func acknowledgeRespawn() {
        elapsed = 0
        shouldRespawn = false
    }
}
