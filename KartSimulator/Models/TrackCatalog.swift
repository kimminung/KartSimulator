import Foundation

/// 앱 번들의 트랙 목록(`Resources/Tracks/track_XX.json`, 원본은 `Tracks/`). 시작 화면 트랙 카드(Issue #43, 디자인 목업 01)와
/// `ImmersiveBoxView`가 같은 정의를 쓴다. 트랙 JSON은 `gen_track.py`로만 만들고 여기서는 읽기만 한다.
/// `TrackDefinition`의 Codable 합성이 기본 격리(main actor)라 카탈로그 전체를 main actor에 둔다 — 쓰는 곳(뷰·박스)도 모두 main actor다.
@MainActor
enum TrackCatalog {
    /// 카드 순서 = 난이도 순. 첫 바퀴(easy) → 노치 하나(normal) → 두 번 꺾기(hard).
    static let trackIDs = ["track_01", "track_02", "track_03"]

    /// 번들에서 한 번만 디코딩해 둔다(카드 썸네일·박스 로드가 같이 쓴다).
    static let tracks: [TrackDefinition] = trackIDs.compactMap(load)

    static func track(id: String) -> TrackDefinition? {
        tracks.first { $0.id == id }
    }

    static func load(id: String) -> TrackDefinition? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json") else {
            print("트랙 리소스를 찾을 수 없습니다: \(id).json")
            return nil
        }
        do {
            return try JSONDecoder().decode(TrackDefinition.self, from: Data(contentsOf: url))
        } catch {
            print("트랙 로드 실패 \(id): \(error)")
            return nil
        }
    }

    /// 난이도 점 개수(5개 중). 디자인 목업 `01_start`의 easy 1·normal 2·hard 4를 그대로 쓴다.
    static func difficultyDots(_ difficulty: String) -> Int {
        switch difficulty {
        case "easy": return 1
        case "normal": return 2
        case "hard": return 4
        default: return 3
        }
    }

    /// 완주 결과가 저장하는 트랙·카트별 최고 총 시간 키(`ImmersiveBoxView.recordResult`와 같은 형식).
    static func bestTotalTimeKey(trackID: String, kartID: String) -> String {
        "bestTotalTime.\(trackID).\(kartID)"
    }

    static func bestTotalTime(trackID: String, kartID: String) -> TimeInterval? {
        UserDefaults.standard.object(forKey: bestTotalTimeKey(trackID: trackID, kartID: kartID)) as? Double
    }
}
