import Foundation

/// 완주 결과(결정 56, Issue #42). `UserDefaults`에 트랙·카트별 최고 총 시간을 저장한다. visionOS 박스와 iOS 레이스 화면이 같이 쓴다.
public struct RaceResult: Equatable, Sendable {
    public let totalTime: TimeInterval
    public let lapTimes: [TimeInterval]
    public let bestLapTime: TimeInterval?
    public let previousBestTotalTime: TimeInterval?
    public let isNewRecord: Bool
    public let kartName: String
    public let trackName: String

    public init(totalTime: TimeInterval, lapTimes: [TimeInterval], bestLapTime: TimeInterval?, previousBestTotalTime: TimeInterval?, isNewRecord: Bool, kartName: String, trackName: String) {
        self.totalTime = totalTime
        self.lapTimes = lapTimes
        self.bestLapTime = bestLapTime
        self.previousBestTotalTime = previousBestTotalTime
        self.isNewRecord = isNewRecord
        self.kartName = kartName
        self.trackName = trackName
    }
}

/// "0:31.42" 형식(디자인 목업 01·07).
public func formatRaceTime(_ t: TimeInterval) -> String {
    let minutes = Int(t) / 60
    let seconds = t - Double(minutes * 60)
    return String(format: "%d:%05.2f", minutes, seconds)
}
