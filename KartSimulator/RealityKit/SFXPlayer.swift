#if os(visionOS)
import RealityKit

/// 엔진음을 뺀 한 발성 효과음 7종(`Assets/sfx/ENGINE.md` 3-4장 "레이스 이벤트"). `wallBump`는
/// 아직 벽 콜리전이 없어(`Docs/TechTask.md` M3) 로드만 해 두고 재생 트리거는 없다.
@MainActor
final class SFXPlayer {
    enum Effect: String, CaseIterable {
        case checkpoint, countdownTick, finish, go, lapComplete, respawn, wallBump
    }

    private let entity: Entity
    private var resources: [Effect: AudioFileResource] = [:]

    init(entity: Entity) {
        self.entity = entity
        for effect in Effect.allCases {
            resources[effect] = try? AudioFileResource.load(named: effect.rawValue + ".wav")
        }
    }

    func play(_ effect: Effect) {
        guard let resource = resources[effect] else { return }
        entity.playAudio(resource)
    }
}
#endif
