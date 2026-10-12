#if os(visionOS)
import AVFoundation
import Foundation

/// 배경음 3곡(디자인 결정 55, `Assets/bgm/README.md`) 재생기. 카트에 붙이는 공간 음향이 아니라 **머리 고정(앰비언트)**이라
/// RealityKit 대신 `AVAudioPlayer`를 쓴다 — 3인칭에서 세계가 돌아도 음악은 돌지 않는다.
///
/// 규칙: 메뉴·대기·카운트다운 재생 안 함 → GO에서 1.0초 페이드 인 → 레이스 중 한 곡 반복 → 완주 2.0초 페이드 아웃 →
/// 종료 0.5초 페이드 아웃. 배경음 버스 −6 dB(효과음 0 dB, 엔진 −6 dB). 곡은 레이스마다 세 곡을 순서대로 돌린다(테크 결정 56).
@MainActor
final class BGMPlayer {
    /// `KartSimulator/Resources/BGM/`의 파일 이름(확장자 m4a). 순서 = 순환 순서.
    static let tracks = ["escape_with_break", "neon_speed_run", "neon_velocity"]
    private static let nextIndexKey = "bgm.nextIndex"

    /// 배경음 버스 −6 dB → 선형 볼륨 약 0.5.
    private let busVolume: Float = 0.5
    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?

    init() {
        // 다른 앱 음악과 섞이는 앰비언트 범주(효과음·엔진음은 RealityKit이 별도로 낸다).
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    /// 다음 곡을 처음부터 `fadeIn`초에 걸쳐 페이드 인하며 반복 재생한다(GO).
    func startNextTrack(fadeIn: TimeInterval = 1.0) {
        let defaults = UserDefaults.standard
        let index = defaults.integer(forKey: Self.nextIndexKey) % Self.tracks.count
        defaults.set((index + 1) % Self.tracks.count, forKey: Self.nextIndexKey)
        let name = Self.tracks[index]
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            print("DEBUG-BGM \(name).m4a 없음 — 배경음 건너뜀")
            return
        }
        fadeTask?.cancel()
        player?.stop()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            fade(to: busVolume, duration: fadeIn, stopAtEnd: false)
            print("DEBUG-BGM 재생 \(name) (다음 \(defaults.integer(forKey: Self.nextIndexKey)))")
        } catch {
            print("DEBUG-BGM 로드 실패 \(name): \(error)")
        }
    }

    /// 페이드 아웃 뒤 정지(완주 2.0초, 종료 0.5초).
    func stop(fadeOut: TimeInterval) {
        guard player != nil else { return }
        fade(to: 0, duration: fadeOut, stopAtEnd: true)
    }

    /// 일시정지용: 볼륨만 낮추거나 되돌린다(−10 dB ≈ 0.32배).
    func duck(_ ducked: Bool, duration: TimeInterval = 0.3) {
        guard player != nil else { return }
        fade(to: ducked ? busVolume * 0.32 : busVolume, duration: duration, stopAtEnd: false)
    }

    private func fade(to target: Float, duration: TimeInterval, stopAtEnd: Bool) {
        fadeTask?.cancel()
        guard let player else { return }
        let start = player.volume
        let steps = max(Int(duration * 30), 1)
        fadeTask = Task { @MainActor [weak self] in
            for i in 1...steps {
                guard !Task.isCancelled, let self, let player = self.player else { return }
                player.volume = start + (target - start) * Float(i) / Float(steps)
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
            }
            guard !Task.isCancelled, let self else { return }
            if stopAtEnd { self.player?.stop(); self.player = nil }
        }
    }
}
#endif
