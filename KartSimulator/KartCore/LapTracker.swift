import Foundation

public struct LapProgress: Equatable, Sendable {
    public var currentLap: Int = 1
    public var checkpointsPassedThisLap: Int = 0
    public var isFinished: Bool = false
}

/// 체크포인트를 순서대로 지났는지, 출발선을 "전진 방향"으로 다시 지났는지를 판정한다.
/// path 인덱스가 뒤로 가거나(역주행) 리스폰으로 크게 점프한 경우는 크로스로 치지 않는다
/// (테크 PRD 12장: "역주행으로 출발선을 지나도 랩이 올라가지 않는다").
public final class LapTracker {
    private let totalLaps: Int
    private let checkpointIndices: [Int]
    private let startIndex: Int
    private let pathCount: Int

    public private(set) var progress = LapProgress()
    private var nextCheckpointOrdinal = 0
    private var lastPathIndex: Int

    public init(track: TrackDefinition) {
        self.totalLaps = track.laps
        self.checkpointIndices = track.checkpoints
        self.startIndex = track.start.pathIndex
        self.pathCount = max(track.path.count, 1)
        self.lastPathIndex = track.start.pathIndex
    }

    /// 매 프레임, 카트의 현재 path 인덱스로 호출한다.
    public func update(pathIndex: Int) {
        guard !progress.isFinished else { return }

        if nextCheckpointOrdinal < checkpointIndices.count {
            let target = checkpointIndices[nextCheckpointOrdinal]
            if didCrossForward(from: lastPathIndex, to: pathIndex, target: target) {
                nextCheckpointOrdinal += 1
                progress.checkpointsPassedThisLap = nextCheckpointOrdinal
            }
        }

        if nextCheckpointOrdinal >= checkpointIndices.count,
           didCrossForward(from: lastPathIndex, to: pathIndex, target: startIndex) {
            nextCheckpointOrdinal = 0
            progress.checkpointsPassedThisLap = 0
            if progress.currentLap >= totalLaps {
                progress.isFinished = true
            } else {
                progress.currentLap += 1
            }
        }

        lastPathIndex = pathIndex
    }

    /// 리스폰 등으로 위치가 순간 이동했을 때, 크로스 판정 없이 기준점만 갱신한다.
    public func resetPosition(pathIndex: Int) {
        lastPathIndex = pathIndex
    }

    private func didCrossForward(from: Int, to: Int, target: Int) -> Bool {
        guard from != to else { return false }
        let forwardDistance = ((to - from) % pathCount + pathCount) % pathCount
        guard forwardDistance <= pathCount / 2 else { return false }

        var i = from
        for _ in 0..<forwardDistance {
            i = (i + 1) % pathCount
            if i == target { return true }
        }
        return false
    }
}
