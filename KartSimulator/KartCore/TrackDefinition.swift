import Foundation

public struct TrackTile: Codable, Sendable {
    public let col: Int
    public let row: Int
    public let type: String
    public let rot: Int
}

public struct TrackPathPoint: Codable, Sendable {
    public let x: Float
    public let z: Float

    public var vector: SIMD2<Float> { SIMD2(x, z) }
}

public struct TrackStart: Codable, Sendable {
    public let pathIndex: Int
    public let heading: Float
}

public struct TrackGrid: Codable, Sendable {
    public let cols: Int
    public let rows: Int
}

public struct TrackTuningOverride: Codable, Sendable {
    public var maxSpeed: Float?
    public var accel: Float?
    public var coastDecel: Float?
    public var brakeDecel: Float?
    public var turnRateLow: Float?
    public var turnRateHigh: Float?
    public var minTurnSpeed: Float?
    public var wallSpeedKeep: Float?
    public var offTrackRespawn: Double?
    public var respawnSpeed: Float?
}

/// `Tracks/track_XX.json`과 1:1 대응 (테크 PRD 7장 스키마). `tiles`/`path`는 `gen_track.py`로만
/// 만들어지므로 여기서는 디코딩만 하고 다시 쓰지 않는다.
public struct TrackDefinition: Codable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let name: String
    public let difficulty: String
    public let seed: Int
    public let laps: Int
    public let tileSize: Float
    public let width: Float
    public let grid: TrackGrid
    public let tiles: [TrackTile]
    public let path: [TrackPathPoint]
    public let start: TrackStart
    public let checkpoints: [Int]
    public let walls: Bool
    public let tuning: TrackTuningOverride?

    /// 타일 바닥(y = 0)에서 노면 윗면까지의 높이. 타일은 64유닛 = `tileSize`이고 노면 윗면은 4유닛
    /// (`Design/tools/tiles.mjs`: base 0~2, road 2~4)이라 `tileSize / 16` = 4 m 타일에서 0.25 m.
    /// 카트는 이 높이에 둔다(결정 49, Issue #23 — 전에는 0으로 두어 모든 카트가 0.25 m 가라앉았다).
    public var roadSurfaceHeight: Float { tileSize / 16 }
}

extension MotionTuning {
    /// 트랙 JSON의 `tuning`에 들어있는 필드만 덮어쓴다 (테크 PRD 7장: "일부만 덮어쓰기 가능").
    public func applying(_ override: TrackTuningOverride?) -> MotionTuning {
        guard let override else { return self }
        var tuning = self
        if let v = override.maxSpeed { tuning.maxSpeed = v }
        if let v = override.accel { tuning.accel = v }
        if let v = override.coastDecel { tuning.coastDecel = v }
        if let v = override.brakeDecel { tuning.brakeDecel = v }
        if let v = override.turnRateLow { tuning.turnRateLow = v }
        if let v = override.turnRateHigh { tuning.turnRateHigh = v }
        if let v = override.minTurnSpeed { tuning.minTurnSpeed = v }
        if let v = override.wallSpeedKeep { tuning.wallSpeedKeep = v }
        if let v = override.offTrackRespawn { tuning.offTrackRespawn = v }
        if let v = override.respawnSpeed { tuning.respawnSpeed = v }
        return tuning
    }
}
