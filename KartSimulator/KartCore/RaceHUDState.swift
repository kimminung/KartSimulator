import Foundation

public enum SessionPhase: Equatable, Sendable {
    case idle
    case ready
    case countdown(Int)
    case racing
    case paused
    case finished
}

/// SwiftUI HUD가 읽는 단일 상태 (테크 PRD 10장). `RaceModel`이 매 프레임 갱신한다.
public struct RaceHUDState: Equatable, Sendable {
    public var phase: SessionPhase = .idle
    public var lap: Int = 1
    public var totalLaps: Int = 0
    public var lapTime: TimeInterval = 0
    public var totalTime: TimeInterval = 0
    public var bestLapTime: TimeInterval?
    /// 완료한 랩의 기록(초). 완주하면 `totalLaps`개가 찬다(결정 56, 결과 화면).
    public var lapTimes: [TimeInterval] = []
    public var speedKmh: Double = 0
    public var drive: DriveState = .stopped
    public var left: HandStatus = HandStatus(tracked: false, pinching: false)
    public var right: HandStatus = HandStatus(tracked: false, pinching: false)
    public var checkpointsPassed: Int = 0
    public var totalCheckpoints: Int = 0
    public var respawning: Bool = false
    /// 미니맵 로컬 좌표(m) — `MinimapProjection`으로 변환한 카트 위치 (테크 PRD 10장, M4).
    public var kartMapPosition: SIMD2<Float> = .zero
    /// 카트 heading(라디안, 트랙 좌표계). 미니맵 마커 회전.
    public var kartHeading: Float = 0

    public init() {}
}
