import AVFoundation
import Foundation
import KeyVoxTTS
import MediaPlayer
import Testing
@testable import KeyVox_iOS

@MainActor
struct TTSSystemPlaybackTests {
    @Test func controllerPublishesPausedReplayMetadataAndTransportAvailability() {
        let controller = TTSSystemPlaybackController()
        defer { clearSystemPlaybackState(controller: controller) }

        controller.update(
            displayText: "A paused replay should surface accurate metadata in system playback controls.",
            voiceName: "Alba",
            isPlaying: false,
            isReplay: true,
            elapsedSeconds: 7.5,
            durationSeconds: 26.96
        )

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        #expect(info?[MPMediaItemPropertyTitle] as? String == "A paused replay should surface accurate metadata in system playback controls.")
        #expect(info?[MPMediaItemPropertyArtist] as? String == "Alba")
        #expect(doubleValue(info?[MPNowPlayingInfoPropertyElapsedPlaybackTime]) == 7.5)
        #expect(doubleValue(info?[MPMediaItemPropertyPlaybackDuration]) == 26.96)
        #expect(doubleValue(info?[MPNowPlayingInfoPropertyPlaybackRate]) == 0)
        #expect(MPRemoteCommandCenter.shared().playCommand.isEnabled == true)
        #expect(MPRemoteCommandCenter.shared().pauseCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled == true)
        #expect(MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled == true)
    }

    @Test func controllerPublishesLivePlaybackWithoutReplayScrubbing() {
        let controller = TTSSystemPlaybackController()
        defer { clearSystemPlaybackState(controller: controller) }

        controller.update(
            displayText: "Live playback should keep system controls limited to transport only.",
            voiceName: "Alba",
            isPlaying: true,
            isReplay: false,
            elapsedSeconds: 3.2,
            durationSeconds: nil
        )

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        #expect(doubleValue(info?[MPNowPlayingInfoPropertyPlaybackRate]) == 1)
        #expect(info?[MPMediaItemPropertyPlaybackDuration] == nil)
        #expect(MPRemoteCommandCenter.shared().playCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().pauseCommand.isEnabled == true)
        #expect(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled == true)
        #expect(MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled == false)
    }

    @Test func controllerClearRemovesNowPlayingInfoAndDisablesCommands() {
        let controller = TTSSystemPlaybackController()
        controller.update(
            displayText: "Replay controls should clear cleanly.",
            voiceName: "Alba",
            isPlaying: true,
            isReplay: true,
            elapsedSeconds: 1,
            durationSeconds: 5
        )

        controller.clear()

        #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo == nil)
        #expect(MPRemoteCommandCenter.shared().playCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().pauseCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled == false)
    }

    @Test func pausedReplaySeekRestoresPausedReplayWithoutSchedulingLiveReplay() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let request = makeRequest(
            text: "Paused replay seeking should restore the paused position without rebuilding a live replay transport.",
            createdAt: 1
        )
        let samples = Array(repeating: Float(0.25), count: 96_000)

        harness.manager.lastReplayableRequest = request
        harness.manager.activeRequest = request
        harness.manager.hasReplayablePlayback = true
        harness.manager.isPlaybackPaused = true
        harness.manager.isReplayingCachedPlayback = true
        harness.manager.playbackCoordinator.restorePausedReplay(
            samples: samples,
            pausedSampleOffset: 24_000
        )
        harness.manager.pausedReplaySampleOffset = 24_000
        harness.manager.updateState(.playing)

        harness.manager.seekReplay(toProgress: 0.75)

        #expect(harness.manager.isPlaybackPaused == true)
        #expect(harness.manager.isReplayingCachedPlayback == true)
        #expect(harness.manager.pausedReplaySampleOffset == 72_000)
        #expect(harness.manager.playbackCoordinator.replayPausedSampleOffsetSnapshot() == 72_000)
        #expect(harness.manager.playbackCoordinator.queuedBufferCount == 0)
        #expect(abs(harness.manager.playbackCoordinator.currentPlaybackProgress - 0.75) < 0.0001)
    }

    @Test func managerPublishesPausedReplayElapsedFromRestoredSampleOffset() {
        let harness = makeHarness(includeSystemPlaybackController: true)
        defer { harness.cleanup() }

        let request = makeRequest(
            text: "Manager system playback refresh should publish the paused replay position that the scrubber restored.",
            createdAt: 2
        )
        let samples = Array(repeating: Float(0.25), count: 96_000)

        harness.manager.lastReplayableRequest = request
        harness.manager.activeRequest = request
        harness.manager.hasReplayablePlayback = true
        harness.manager.isPlaybackPaused = true
        harness.manager.isReplayingCachedPlayback = true
        harness.manager.playbackCoordinator.restorePausedReplay(
            samples: samples,
            pausedSampleOffset: 72_000
        )
        harness.manager.pausedReplaySampleOffset = 72_000
        harness.manager.updateState(.playing)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        #expect(doubleValue(info?[MPNowPlayingInfoPropertyElapsedPlaybackTime]) == 3)
        #expect(doubleValue(info?[MPMediaItemPropertyPlaybackDuration]) == 4)
        #expect(doubleValue(info?[MPNowPlayingInfoPropertyPlaybackRate]) == 0)
        #expect(MPRemoteCommandCenter.shared().playCommand.isEnabled == true)
        #expect(MPRemoteCommandCenter.shared().pauseCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled == true)
    }

    @Test func pausingWhilePreservingRecordingHandsPlaybackOffToSpokenAudioSession() {
        let audioSession = SpyPlaybackAudioSession()
        let coordinator = TTSPlaybackCoordinator(audioSession: audioSession)
        coordinator.setAudioSessionMode(.playbackWhilePreservingRecording)
        coordinator.didStartPlayback = true
        coordinator.overrideIsPlayerNodePlaying = true

        coordinator.pause()

        #expect(coordinator.isPaused == true)
        #expect(audioSession.activeCalls == [
            .init(active: false, options: []),
            .init(active: true, options: [])
        ])
        #expect(audioSession.policyCategoryCalls == [
            .init(category: .playback, mode: .spokenAudio, policy: .longFormAudio, options: [])
        ])
        #expect(audioSession.portOverrides == [.none])
        #expect(coordinator.hasHandedOffPausedPlaybackSession == true)
    }

    @Test func stoppingAfterPausedRecordingPreservationReleasesHandedOffPlaybackSession() {
        let audioSession = SpyPlaybackAudioSession()
        let coordinator = TTSPlaybackCoordinator(audioSession: audioSession)
        coordinator.setAudioSessionMode(.playbackWhilePreservingRecording)
        coordinator.didStartPlayback = true
        coordinator.overrideIsPlayerNodePlaying = true

        coordinator.pause()
        coordinator.stop()

        #expect(audioSession.activeCalls == [
            .init(active: false, options: []),
            .init(active: true, options: []),
            .init(active: false, options: [.notifyOthersOnDeactivation])
        ])
        #expect(coordinator.hasHandedOffPausedPlaybackSession == false)
    }

    @Test func pausingPlainPlaybackDoesNotDeactivateOrHandoffAudioSession() {
        let audioSession = SpyPlaybackAudioSession()
        let coordinator = TTSPlaybackCoordinator(audioSession: audioSession)
        coordinator.setAudioSessionMode(.playback)
        coordinator.didStartPlayback = true
        coordinator.overrideIsPlayerNodePlaying = true

        coordinator.pause()

        #expect(coordinator.isPaused == true)
        #expect(audioSession.activeCalls.isEmpty)
        #expect(audioSession.policyCategoryCalls.isEmpty)
        #expect(audioSession.plainCategoryCalls.isEmpty)
        #expect(audioSession.portOverrides.isEmpty)
    }

    @Test func finishingWhilePreservingRecordingRetainsPlaybackSessionAndSkipsMonitoringRepair() async {
        let audioSession = SpyPlaybackAudioSession()
        let harness = makeHarness(
            includeSystemPlaybackController: true,
            playbackCoordinator: TTSPlaybackCoordinator(audioSession: audioSession)
        )
        defer { harness.cleanup() }

        let request = makeRequest(
            text: "Finished warm-session playback should stay replay-ready instead of leaving system transport in a broken state.",
            createdAt: 3
        )
        let samples = Array(repeating: Float(0.25), count: 96_000)
        var teardownCallCount = 0

        harness.manager.playbackCoordinator.setAudioSessionMode(.playbackWhilePreservingRecording)
        harness.manager.activeRequest = request
        harness.manager.lastReplayableRequest = request
        harness.manager.playbackCoordinator.restoreReplayablePlayback(samples: samples)
        harness.manager.hasReplayablePlayback = true
        harness.manager.onWillTeardownPlayback = {
            teardownCallCount += 1
        }

        harness.manager.finishPlayback()
        await Task.yield()
        await Task.yield()

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        #expect(harness.manager.state == .finished)
        #expect(teardownCallCount == 0)
        #expect(audioSession.activeCalls == [
            .init(active: false, options: []),
            .init(active: true, options: [])
        ])
        #expect(audioSession.policyCategoryCalls == [
            .init(category: .playback, mode: .spokenAudio, policy: .longFormAudio, options: [])
        ])
        #expect(audioSession.portOverrides == [.none])
        #expect(doubleValue(info?[MPNowPlayingInfoPropertyPlaybackRate]) == 0)
        #expect(MPRemoteCommandCenter.shared().playCommand.isEnabled == true)
        #expect(MPRemoteCommandCenter.shared().pauseCommand.isEnabled == false)
        #expect(MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled == true)
    }

    private func makeHarness(
        includeSystemPlaybackController: Bool = false,
        playbackCoordinator: TTSPlaybackCoordinator? = nil
    ) -> TTSSystemPlaybackHarness {
        let suiteName = "TTSSystemPlaybackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let replayCache = TTSReplayCache()
        replayCache.clear()

        let systemPlaybackController = includeSystemPlaybackController
            ? TTSSystemPlaybackController()
            : nil
        let resolvedPlaybackCoordinator = playbackCoordinator ?? TTSPlaybackCoordinator()

        let manager = TTSManager(
            settingsStore: AppSettingsStore(defaults: defaults),
            appHaptics: StubAppHaptics(),
            keyboardBridge: KeyVoxKeyboardBridge(),
            engine: StubTTSEngine(),
            playbackCoordinator: resolvedPlaybackCoordinator,
            purchaseGate: StubTTSPurchaseGate(),
            systemPlaybackController: systemPlaybackController,
            replayCache: replayCache
        )

        return TTSSystemPlaybackHarness(
            defaults: defaults,
            replayCache: replayCache,
            systemPlaybackController: systemPlaybackController,
            manager: manager,
            suiteName: suiteName
        )
    }

    private func makeRequest(text: String, createdAt: TimeInterval) -> KeyVox_iOS.KeyVoxTTSRequest {
        KeyVox_iOS.KeyVoxTTSRequest(
            id: UUID(),
            text: text,
            createdAt: createdAt,
            sourceSurface: KeyVox_iOS.KeyVoxTTSRequestSourceSurface.app,
            voiceID: AppSettingsStore.TTSVoice.alba.rawValue,
            kind: KeyVox_iOS.KeyVoxTTSRequestKind.speakClipboardText
        )
    }

    private func clearSystemPlaybackState(controller: TTSSystemPlaybackController?) {
        controller?.clear()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let double as Double:
            return double
        default:
            return nil
        }
    }
}

private final class SpyPlaybackAudioSession: TTSPlaybackAudioSessionControlling {
    struct ActiveCall: Equatable {
        let active: Bool
        let options: AVAudioSession.SetActiveOptions
    }

    struct PolicyCategoryCall: Equatable {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let policy: AVAudioSession.RouteSharingPolicy
        let options: AVAudioSession.CategoryOptions
    }

    var currentOutputPortTypes: [AVAudioSession.Port] = []
    private(set) var activeCalls: [ActiveCall] = []
    private(set) var policyCategoryCalls: [PolicyCategoryCall] = []
    private(set) var plainCategoryCalls: [(category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)] = []
    private(set) var portOverrides: [AVAudioSession.PortOverride] = []

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        policy: AVAudioSession.RouteSharingPolicy,
        options: AVAudioSession.CategoryOptions
    ) throws {
        policyCategoryCalls.append(.init(category: category, mode: mode, policy: policy, options: options))
    }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        plainCategoryCalls.append((category: category, mode: mode, options: options))
    }

    func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws {
        portOverrides.append(portOverride)
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        activeCalls.append(.init(active: active, options: options))
    }
}

@MainActor
private struct TTSSystemPlaybackHarness {
    let defaults: UserDefaults
    let replayCache: TTSReplayCache
    let systemPlaybackController: TTSSystemPlaybackController?
    let manager: TTSManager
    let suiteName: String

    func cleanup() {
        systemPlaybackController?.clear()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        replayCache.clear()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private struct StubAppHaptics: AppHapticsEmitting {
    func emit(_ event: AppHapticEvent) {}
    func light() {}
    func medium() {}
    func selection() {}
    func success() {}
    func warning() {}
}

private struct StubTTSEngine: TTSEngine {
    func prepareIfNeeded() async throws {}
    func prewarmVoiceIfNeeded(voiceID: String) async throws {}
    func requestForegroundSynthesisImmediately() {}
    func requestBackgroundContinuationImmediately() {}
    func prepareForForegroundSynthesis() async {}
    func prepareForBackgroundContinuation() async {}

    func makeAudioStream(
        for text: String,
        voiceID: String,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private final class StubTTSPurchaseGate: TTSPurchaseGating {
    var isTTSUnlocked: Bool = true
    var remainingFreeTTSSpeaksToday: Int = 2
    var canStartNewTTSSpeak: Bool = true

    func refreshUsageIfNeeded() {}
    func presentUnlockSheet() {}
    func dismissUnlockSheet() {}
    func consumeFreeTTSSpeakIfNeeded() {}
}
