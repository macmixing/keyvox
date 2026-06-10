import AVFAudio
import Combine
import Foundation

@MainActor
final class TTSPreviewPlayer: NSObject, ObservableObject {
    @Published private(set) var activePreviewResourceName: String?
    @Published private(set) var isPlaying = false

    private let appHaptics: AppHapticsEmitting
    private let audioSession: AVAudioSession
    private let isRecordingSessionActiveProvider: @MainActor () -> Bool
    private let preferBuiltInMicrophoneProvider: @MainActor () -> Bool
    private var player: AVAudioPlayer?
    private var hasActivatedAudioSession = false
    private var shouldDeactivateAudioSessionOnStop = false

    init(
        appHaptics: AppHapticsEmitting,
        audioSession: AVAudioSession = .sharedInstance(),
        isRecordingSessionActiveProvider: (@MainActor () -> Bool)? = nil,
        preferBuiltInMicrophoneProvider: (@MainActor () -> Bool)? = nil
    ) {
        self.appHaptics = appHaptics
        self.audioSession = audioSession
        self.isRecordingSessionActiveProvider = isRecordingSessionActiveProvider ?? { false }
        self.preferBuiltInMicrophoneProvider = preferBuiltInMicrophoneProvider ?? { true }
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
        resetPlaybackState(deactivateAudioSession: true)
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
            resumeCurrentPlayback()
        }
    }

    private func startPlayback(resourceName: String) {
        guard let url = previewURL(resourceName: resourceName) else {
            stop()
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.startPlayback(resourceName: resourceName, url: url)
            } catch {
                Self.log("Failed to play preview for \(resourceName): \(String(describing: error))")
                self.stop()
            }
        }
    }

    private func startPlayback(resourceName: String, url: URL) async throws {
            resetPlaybackState(deactivateAudioSession: false)
            try await configureAudioSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            activePreviewResourceName = resourceName
            appHaptics.light()
            player.play()
            isPlaying = true
    }

    private func resetPlaybackState(deactivateAudioSession: Bool) {
        let previousPlayer = player
        player = nil
        activePreviewResourceName = nil
        isPlaying = false

        previousPlayer?.delegate = nil
        previousPlayer?.stop()

        if deactivateAudioSession, hasActivatedAudioSession, shouldDeactivateAudioSessionOnStop {
            deactivateAudioSessionIfNeeded()
        }
    }

    private func resumeCurrentPlayback() {
        guard let player else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.configureAudioSession()
                self.appHaptics.light()
                player.play()
                self.isPlaying = true
            } catch {
                Self.log(
                    "Failed to resume preview for \(self.activePreviewResourceName ?? "unknown"): \(String(describing: error))"
                )
                self.stop()
            }
        }
    }

    private func configureAudioSession() async throws {
        if isRecordingSessionActiveProvider() {
            let bluetoothRoutePolicy = AudioBluetoothRoutePolicy(
                preferBuiltInMicrophone: preferBuiltInMicrophoneProvider()
            )
            var categoryOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .mixWithOthers]
            categoryOptions.formUnion(bluetoothRoutePolicy.bluetoothCategoryOptions)
            let resolvedCategoryOptions = categoryOptions
            try await performAudioSessionOperation { audioSession in
                try audioSession.setCategory(.playAndRecord, mode: .default, options: resolvedCategoryOptions)
                let isUsingBuiltInReceiver = audioSession.currentRoute.outputs.contains {
                    $0.portType == .builtInReceiver
                }
                try? audioSession.overrideOutputAudioPort(isUsingBuiltInReceiver ? .speaker : .none)
            }
            shouldDeactivateAudioSessionOnStop = false
        } else {
            try? await deactivateAudioSession()
            try await performAudioSessionOperation { audioSession in
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try? audioSession.overrideOutputAudioPort(.none)
            }
            shouldDeactivateAudioSessionOnStop = true
        }
        try await activateAudioSession()
        hasActivatedAudioSession = true
    }

    private func deactivateAudioSessionIfNeeded() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.deactivateAudioSession(notifyOthers: true)
            self.hasActivatedAudioSession = false
            self.shouldDeactivateAudioSessionOnStop = false
        }
    }

    private func activateAudioSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                audioSession.activate(options: []) { activated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if activated {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CocoaError(.featureUnsupported))
                    }
                }
            }
        } else {
            try await performAudioSessionOperation { audioSession in
                try audioSession.setActive(true)
            }
        }
    }

    private func deactivateAudioSession(notifyOthers: Bool = false) async throws {
        if #available(iOS 27.0, *) {
            let options: AVAudioSessionDeactivationOptions = notifyOthers ? [.notifyOthersOnDeactivation] : []
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                audioSession.deactivate(options: options) { deactivated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if deactivated {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CocoaError(.featureUnsupported))
                    }
                }
            }
        } else {
            let options: AVAudioSession.SetActiveOptions = notifyOthers ? [.notifyOthersOnDeactivation] : []
            try await performAudioSessionOperation { audioSession in
                try audioSession.setActive(false, options: options)
            }
        }
    }

    private func performAudioSessionOperation(
        _ operation: @escaping @Sendable (AVAudioSession) throws -> Void
    ) async throws {
        let audioSession = audioSession
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try operation(audioSession)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func log(_ message: String) {
        #if DEBUG
        NSLog("[TTSPreviewPlayer] %@", message)
        #endif
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
            Self.log("Decode error: \(String(describing: error))")
            guard self?.player === player else { return }
            self?.stop()
        }
    }
}
