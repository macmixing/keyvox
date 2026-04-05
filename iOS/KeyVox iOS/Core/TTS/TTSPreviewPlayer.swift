import AVFAudio
import Combine
import Foundation

@MainActor
final class TTSPreviewPlayer: NSObject, ObservableObject {
    @Published private(set) var activePreviewResourceName: String?
    @Published private(set) var isPlaying = false

    private let appHaptics: AppHapticsEmitting
    private var player: AVAudioPlayer?

    init(appHaptics: AppHapticsEmitting) {
        self.appHaptics = appHaptics
        super.init()
    }

    func togglePlayback(resourceName: String) {
        if activePreviewResourceName == resourceName {
            toggleCurrentPlayback()
            return
        }

        startPlayback(resourceName: resourceName)
    }

    func togglePlayback(for voice: AppSettingsStore.TTSVoice) {
        togglePlayback(resourceName: previewResourceName(for: voice))
    }

    func isActive(resourceName: String) -> Bool {
        activePreviewResourceName == resourceName
    }

    func isActive(for voice: AppSettingsStore.TTSVoice) -> Bool {
        isActive(resourceName: previewResourceName(for: voice))
    }

    func stop() {
        player?.stop()
        player = nil
        activePreviewResourceName = nil
        isPlaying = false
    }

    func hasPreview(resourceName: String) -> Bool {
        previewURL(resourceName: resourceName) != nil
    }

    func hasPreview(for voice: AppSettingsStore.TTSVoice) -> Bool {
        hasPreview(resourceName: previewResourceName(for: voice))
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

    private func startPlayback(resourceName: String) {
        guard let url = previewURL(resourceName: resourceName) else {
            stop()
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            activePreviewResourceName = resourceName
            appHaptics.light()
            player.play()
            isPlaying = true
        } catch {
            NSLog(
                "[TTSPreviewPlayer] Failed to play preview for %@: %@",
                resourceName,
                String(describing: error)
            )
            stop()
        }
    }

    private func previewResourceName(for voice: AppSettingsStore.TTSVoice) -> String {
        "\(voice.rawValue)-preview"
    }

    private func previewURL(resourceName: String) -> URL? {
        Bundle.main.url(
            forResource: resourceName,
            withExtension: "m4a",
            subdirectory: "TTSVoicePreviews"
        )
    }
}

extension TTSPreviewPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.stop()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            NSLog(
                "[TTSPreviewPlayer] Decode error: %@",
                String(describing: error)
            )
            guard self?.player === player else { return }
            self?.stop()
        }
    }
}
