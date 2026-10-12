#if os(visionOS) || os(iOS)
import RealityKit

/// `EngineSoundMachine`이 내놓는 명령을 실제로 재생한다. 엔진 버스(-6dB)는 `Assets/sfx/ENGINE.md`
/// 3-5장대로 — 효과음(한 발성 SFX, 피크 -12dBFS)이 엔진 위로 또렷이 들리게 하기 위함이다.
@MainActor
final class EngineAudioPlayer {
    private var controllers: [EngineVoice: AudioPlaybackController] = [:]
    private var generation: [EngineVoice: Int] = [:]
    private let busDb: Double = -6.0
    private let silentDb: Double = -80.0

    init(kart: Entity) throws {
        kart.components.set(SpatialAudioComponent())
        for voice in EngineVoice.allCases {
            let resource = try AudioFileResource.load(
                named: voice.file + ".wav",
                configuration: .init(shouldLoop: voice.loops)
            )
            controllers[voice] = kart.prepareAudio(resource)
        }
    }

    func run(_ commands: [EngineCommand]) {
        for command in commands {
            switch command {
            case let .play(voice, rate, gainDb, fadeIn):
                guard let player = controllers[voice] else { continue }
                generation[voice, default: 0] += 1
                player.stop()
                player.speed = rate
                if fadeIn > 0 {
                    player.gain = silentDb
                    player.play()
                    player.fade(to: busDb + gainDb, duration: fadeIn)
                } else {
                    player.gain = busDb + gainDb
                    player.play()
                }
            case let .stop(voice, fadeOut):
                guard let player = controllers[voice], player.isPlaying else { continue }
                let gen = generation[voice, default: 0]
                player.fade(to: silentDb, duration: fadeOut)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(fadeOut))
                    if generation[voice] == gen { player.stop() }
                }
            case let .set(voice, rate, gainDb):
                guard let player = controllers[voice] else { continue }
                player.speed = rate
                if let gainDb { player.gain = busDb + gainDb }
            }
        }
    }
}
#endif
