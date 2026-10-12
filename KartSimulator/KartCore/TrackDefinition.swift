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
    /// 스키마 2: 경사·루프에서 진행 방향 y 성분에 곱하는 중력 가속도(m/s²). `accel`(3)보다 크면 루프에서 스로틀 없이는 못 오른다.
    public var gravity: Float?
}

/// 미니맵 색 등 테마(컨셉) 정보(스키마 2, `gen_circuit.py`의 THEMES). 노면 메시 색은 Blender가 굽고, 앱은 미니맵 색만 읽는다.
public struct TrackTheme: Codable, Sendable {
    public struct Minimap: Codable, Sendable {
        public let road: String
        public let edge: String
        public let disc: String
        public let accent: String
    }
    public let id: String
    public let ground: String
    public let minimap: Minimap?
}

/// 같은 특징(루프·헬릭스·시케인…)이 이어지는 프레임 구간(스키마 2). 미니맵 라벨에 쓴다.
public struct TrackSection: Codable, Sendable {
    public let feature: String
    public let from: Int
    public let to: Int
}

/// `Tracks/track_XX.json`(스키마 1, 격자 타일)·`Tracks/circuit_XX.json`(스키마 2, 3D 서킷)과 1:1 대응 (테크 PRD 7장 스키마,
/// 결정 58). `tiles`/`path`/`frames`는 생성 스크립트(`gen_track.py`/`gen_circuit.py`)로만 만들어지므로 여기서는 디코딩만 한다.
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
    // ---- 스키마 2(서킷) ----
    /// 3D 프레임 [x, y, z, tx, ty, tz, ux, uy, uz, kyaw]. `path[i]`와 같은 점.
    public let frames: [[Float]]?
    /// 노면 USDZ 리소스 이름(`Resources/Tracks/<model>.usdz`). 없으면 타일을 깐다.
    public let model: String?
    public let difficultyDots: Int?
    public let description: String?
    public let features: [String]?
    public let length: Float?
    public let theme: TrackTheme?
    public let sections: [TrackSection]?

    public init(
        schemaVersion: Int, id: String, name: String, difficulty: String, seed: Int, laps: Int, tileSize: Float, width: Float,
        grid: TrackGrid, tiles: [TrackTile], path: [TrackPathPoint], start: TrackStart, checkpoints: [Int], walls: Bool,
        tuning: TrackTuningOverride?, frames: [[Float]]? = nil, model: String? = nil, difficultyDots: Int? = nil,
        description: String? = nil, features: [String]? = nil, length: Float? = nil, theme: TrackTheme? = nil, sections: [TrackSection]? = nil
    ) {
        self.schemaVersion = schemaVersion; self.id = id; self.name = name; self.difficulty = difficulty; self.seed = seed
        self.laps = laps; self.tileSize = tileSize; self.width = width; self.grid = grid; self.tiles = tiles; self.path = path
        self.start = start; self.checkpoints = checkpoints; self.walls = walls; self.tuning = tuning; self.frames = frames
        self.model = model; self.difficultyDots = difficultyDots; self.description = description; self.features = features
        self.length = length; self.theme = theme; self.sections = sections
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, difficulty, seed, laps, tileSize, width, grid, tiles, path, start, checkpoints, walls, tuning
        case frames, model, difficultyDots, description, features, length, theme, sections
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        difficulty = try c.decode(String.self, forKey: .difficulty)
        seed = try c.decodeIfPresent(Int.self, forKey: .seed) ?? 0
        laps = try c.decode(Int.self, forKey: .laps)
        tileSize = try c.decodeIfPresent(Float.self, forKey: .tileSize) ?? 4
        width = try c.decodeIfPresent(Float.self, forKey: .width) ?? 3
        grid = try c.decodeIfPresent(TrackGrid.self, forKey: .grid) ?? TrackGrid(cols: 0, rows: 0)
        tiles = try c.decodeIfPresent([TrackTile].self, forKey: .tiles) ?? []
        path = try c.decode([TrackPathPoint].self, forKey: .path)
        start = try c.decode(TrackStart.self, forKey: .start)
        checkpoints = try c.decode([Int].self, forKey: .checkpoints)
        walls = try c.decodeIfPresent(Bool.self, forKey: .walls) ?? true
        tuning = try c.decodeIfPresent(TrackTuningOverride.self, forKey: .tuning)
        frames = try c.decodeIfPresent([[Float]].self, forKey: .frames)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        difficultyDots = try c.decodeIfPresent(Int.self, forKey: .difficultyDots)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        features = try c.decodeIfPresent([String].self, forKey: .features)
        length = try c.decodeIfPresent(Float.self, forKey: .length)
        theme = try c.decodeIfPresent(TrackTheme.self, forKey: .theme)
        sections = try c.decodeIfPresent([TrackSection].self, forKey: .sections)
    }

    /// 3D 서킷(스키마 2)인가. 프레임이 있으면 노면 높이는 프레임 y에 들어 있고, 노면 모델은 `model` USDZ다.
    public var isCircuit: Bool { frames != nil }

    /// 타일 바닥(y = 0)에서 노면 윗면까지의 높이. 타일은 64유닛 = `tileSize`이고 노면 윗면은 4유닛
    /// (`Design/tools/tiles.mjs`: base 0~2, road 2~4)이라 `tileSize / 16` = 4 m 타일에서 0.25 m.
    /// 카트는 이 높이에 둔다(결정 49, Issue #23 — 전에는 0으로 두어 모든 카트가 0.25 m 가라앉았다).
    public var roadSurfaceHeight: Float { tileSize / 16 }

    /// 스플라인을 만들 때 평면 `path`에 더하는 노면 높이. 서킷은 프레임 y가 곧 노면이라 0.
    public var surfaceHeight: Float { isCircuit ? 0 : roadSurfaceHeight }
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
        if let v = override.gravity { tuning.gravity = v }
        return tuning
    }
}
