import Foundation
import Observation

/// RealityKit 시스템과 SwiftUI HUD 사이의 유일한 접점 (테크 PRD 2·10장).
/// `ImmersiveBoxView`가 매 프레임 `update*` 메서드를 호출해 채우고, HUD는 `hud`만 읽는다.
@MainActor
@Observable
public final class RaceModel {
    public private(set) var hud = RaceHUDState()

    public init() {}

    /// 새 레이스. 카운트다운(3)부터 시작하고, `countdown(_:)`·`go()`로 단계가 넘어간다(결정 56).
    /// 카운트다운 동안 `updateMotion`은 시간을 쌓지 않고, 호출자(`ImmersiveBoxView`)가 입력도 잠근다.
    public func start(totalLaps: Int) {
        hud = RaceHUDState()
        hud.totalLaps = totalLaps
        hud.phase = .countdown(3)
    }

    /// 카운트다운 숫자 갱신(3 → 2 → 1).
    public func countdown(_ remaining: Int) {
        hud.phase = .countdown(remaining)
    }

    /// GO — 주행 시작. 타이머가 여기서부터 흐른다.
    public func go() {
        hud.phase = .racing
    }

    public var isRacing: Bool { hud.phase == .racing }
    public var isFinished: Bool { hud.phase == .finished }

    public func updateDrive(_ drive: DriveState, left: HandStatus, right: HandStatus) {
        hud.drive = drive
        hud.left = left
        hud.right = right
    }

    public func updateMotion(speedMetersPerSecond: Float, deltaTime: TimeInterval) {
        // 후진 중엔 속도가 음수라, 속도계에는 크기만 보여준다(방향은 HUD의 `drive` 텍스트로 구분).
        hud.speedKmh = Double(abs(speedMetersPerSecond)) * 3.6
        guard hud.phase == .racing else { return }
        hud.lapTime += deltaTime
        hud.totalTime += deltaTime
    }

    public func updateLap(_ progress: LapProgress, totalCheckpoints: Int) {
        guard hud.phase == .racing else {
            hud.checkpointsPassed = progress.checkpointsPassedThisLap
            hud.totalCheckpoints = totalCheckpoints
            return
        }
        let lapCompleted = progress.currentLap != hud.lap || (progress.isFinished && hud.lapTimes.count < hud.totalLaps)
        if lapCompleted {
            let completedLapTime = hud.lapTime
            hud.lapTimes.append(completedLapTime)
            hud.bestLapTime = hud.bestLapTime.map { min($0, completedLapTime) } ?? completedLapTime
            hud.lapTime = 0
        }
        hud.lap = progress.isFinished ? hud.totalLaps : progress.currentLap
        hud.checkpointsPassed = progress.checkpointsPassedThisLap
        hud.totalCheckpoints = totalCheckpoints
        if progress.isFinished {
            hud.phase = .finished
        }
    }

    /// 미니맵용 카트 위치(미니맵 로컬 m)·heading (테크 PRD 10장 `MinimapSyncSystem` 입력).
    public func updateMap(position: SIMD2<Float>, heading: Float) {
        hud.kartMapPosition = position
        hud.kartHeading = heading
    }

    /// 지금은 "센터라인 이탈 중" 상태를 그대로 보여준다. 실제 "복귀 중(0.5s)" 연출은
    /// 타일/벽 에셋이 생기는 M3 후반~M5에서 다듬는다.
    public func setRespawning(_ respawning: Bool) {
        hud.respawning = respawning
    }
}
