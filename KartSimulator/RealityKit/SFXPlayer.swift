#if os(visionOS) || os(iOS)
import RealityKit

/// 엔진음을 뺀 한 발성 효과음(`Assets/sfx/ENGINE.md` 3-4장 "레이스 이벤트" + 결정 63·65의 디자인 전달 M4A).
/// 이벤트 이름은 유지하고 파일만 바꾼다: `countdownTick` → `stttt.m4a`, `go` → `start.m4a`, `lapComplete` → `cue_middle_lap.m4a`.
/// 새 이벤트: `record`(신기록, `cue_record.m4a`), `error`(출발 전 입력 등, `cue_error.m4a`).
@MainActor
final class SFXPlayer {
    enum Effect: String, CaseIterable {
        case checkpoint, countdownTick, finish, go, lapComplete, respawn, wallBump, record, error

        /// 번들 파일 이름(확장자 포함). 디자인 전달 M4A가 있는 이벤트는 그쪽을 쓴다.
        var fileName: String {
            switch self {
            case .countdownTick: return "stttt.m4a"
            case .go: return "start.m4a"
            case .lapComplete: return "cue_middle_lap.m4a"
            case .record: return "cue_record.m4a"
            case .error: return "cue_error.m4a"
            case .checkpoint, .finish, .respawn, .wallBump: return rawValue + ".wav"
            }
        }
    }

    private let entity: Entity
    private var resources: [Effect: AudioFileResource] = [:]
    private var controllers: [AudioPlaybackController] = []

    init(entity: Entity) {
        self.entity = entity
        for effect in Effect.allCases {
            resources[effect] = try? AudioFileResource.load(named: effect.fileName)
        }
    }

    /// 매번 새 재생 인스턴스를 만든다 — 준비음처럼 긴 소리를 되감아 꼬리를 끊지 않는다(결정 63).
    func play(_ effect: Effect) {
        guard let resource = resources[effect] else { return }
        let controller = entity.playAudio(resource)
        controllers.append(controller)
        if controllers.count > 8 { controllers.removeFirst(controllers.count - 8) }
    }

    /// 카운트다운 취소·다시 시작·닫기 때 울리고 있는 효과음을 멈춘다(결정 63 "이전 카운트다운의 인스턴스 정리").
    func stopAll() {
        for controller in controllers { controller.stop() }
        controllers.removeAll()
    }
}
#endif
