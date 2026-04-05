import AVFAudio
import Combine
import Foundation

@MainActor
final class TTSVoicePreviewPlayer: NSObject, ObservableObject {
    @Published private(set) var activeVoice: AppSettingsStore.TTSVoice?
    @Published private(set) var isPlaying = false

    private let appHaptics: AppHapticsEmitting
    private var player: AVAudioPlayer?

    init(appHaptics: AppHapticsEmitting) {
        self.appHaptics = appHaptics
        super.init()
    }

    func togglePlayback(for voice: AppSettingsStore.TTSVoice) {
        if activeVoice == voice {
            toggleCurrentPlayback()
            return
        }

        startPlayback(for: voice)
    }

    func isActive(for voice: AppSettingsStore.TTSVoice) -> Bool {
        activeVoice == voice
    }

    func stop() {
        player?.stop()
        player = nil
        activeVoice = nil
        isPlaying = false
    }

    func hasPreview(for voice: AppSettingsStore.TTSVoice) -> Bool {
        previewURL(for: voice) != nil
    }

    private func toggleCurrentPlayback() {
        guard let player else { return }

        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            appHaptics.light()
            player.play()
            isPlaying = true
        }
    }

    private func startPlayback(for voice: AppSettingsStore.TTSVoice) {
        guard let url = previewURL(for: voice) else {
            stop()
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            activeVoice = voice
            appHaptics.light()
            player.play()
            isPlaying = true
        } catch {
            NSLog(
                "[TTSVoicePreviewPlayer] Failed to play preview for %@: %@",
                voice.rawValue,
                String(describing: error)
            )
            stop()
        }
    }

    private func previewURL(for voice: AppSettingsStore.TTSVoice) -> URL? {
        Bundle.main.url(
            forResource: "\(voice.rawValue)-preview",
            withExtension: "m4a",
            subdirectory: "TTSVoicePreviews"
        )
    }
}

extension TTSVoicePreviewPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.stop()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            NSLog(
                "[TTSVoicePreviewPlayer] Decode error: %@",
                String(describing: error)
            )
            guard self?.player === player else { return }
            self?.stop()
        }
    }
}
