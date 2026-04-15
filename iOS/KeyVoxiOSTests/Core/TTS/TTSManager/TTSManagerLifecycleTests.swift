import AVFAudio
import Foundation
import KeyVoxTTS
import Testing
import UIKit
@testable import KeyVox_iOS

@MainActor
struct TTSManagerLifecycleTests {
    @Test func appDidBecomeActiveRequestsImmediateForegroundSynthesis() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.playbackCoordinator.isBackgroundTransitionArmed = true

        harness.manager.handleAppDidBecomeActive()
        await settleLifecycleTasks()

        #expect(harness.engine.immediateForegroundRequestCount == 1)
        #expect(harness.engine.prepareForegroundCallCount == 1)
        #expect(harness.manager.playbackCoordinator.isBackgroundTransitionArmed == false)
    }

    @Test func appWillResignActiveRequestsBackgroundContinuationForNormalModePlayback() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.fastPlaybackModeEnabled = false
        harness.manager.activeRequest = makeRequest(createdAt: 1)
        harness.manager.hasStartedPlaybackForActiveRequest = true
        harness.manager.updateState(.playing)

        harness.manager.handleAppWillResignActive()
        await settleLifecycleTasks()

        #expect(harness.engine.immediateBackgroundRequestCount == 1)
        #expect(harness.engine.prepareBackgroundCallCount == 1)
        #expect(harness.manager.playbackCoordinator.isBackgroundTransitionArmed)
    }

    @Test func appWillResignActivePausesUnsafeFastModePlayback() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.fastPlaybackModeEnabled = true
        harness.manager.activeRequest = makeRequest(createdAt: 2)
        harness.manager.hasStartedPlaybackForActiveRequest = true
        harness.manager.updateState(.playing)
        armPlaybackCoordinatorForPause(harness.manager.playbackCoordinator)

        harness.manager.handleAppWillResignActive()
        await settleLifecycleTasks()

        #expect(harness.engine.immediateBackgroundRequestCount == 1)
        #expect(harness.engine.prepareBackgroundCallCount == 1)
        #expect(harness.manager.isPlaybackPaused)
        #expect(harness.manager.playbackCoordinator.isPaused)
        #expect(harness.manager.playbackCoordinator.isBackgroundTransitionArmed)
    }

    @Test func protectedDataLockContinuesSafeFastModePlaybackWithoutPausing() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.fastPlaybackModeEnabled = true
        harness.manager.activeRequest = makeRequest(createdAt: 3)
        harness.manager.hasStartedPlaybackForActiveRequest = true
        harness.manager.updateState(.playing)
        harness.manager.playbackCoordinator.fastModeEnabled = true
        harness.manager.playbackCoordinator.didStartPlayback = true
        harness.manager.playbackCoordinator.isPaused = false
        harness.manager.playbackCoordinator.isFastModeBackgroundSafeState = true
        harness.manager.playbackCoordinator.hasObservedFastModeBackgroundSafeCompute = true

        harness.manager.handleProtectedDataWillBecomeUnavailableNotification(
            Notification(name: UIApplication.protectedDataWillBecomeUnavailableNotification)
        )
        await settleLifecycleTasks()

        #expect(harness.engine.immediateBackgroundRequestCount == 1)
        #expect(harness.engine.prepareBackgroundCallCount == 1)
        #expect(harness.manager.isPlaybackPaused == false)
    }

    @Test func protectedDataLockPausesUnsafeFastModePlayback() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.fastPlaybackModeEnabled = true
        harness.manager.activeRequest = makeRequest(createdAt: 4)
        harness.manager.hasStartedPlaybackForActiveRequest = true
        harness.manager.updateState(.playing)
        armPlaybackCoordinatorForPause(harness.manager.playbackCoordinator)

        harness.manager.handleProtectedDataWillBecomeUnavailableNotification(
            Notification(name: UIApplication.protectedDataWillBecomeUnavailableNotification)
        )
        await settleLifecycleTasks()

        #expect(harness.engine.immediateBackgroundRequestCount == 1)
        #expect(harness.engine.prepareBackgroundCallCount == 1)
        #expect(harness.manager.isPlaybackPaused)
        #expect(harness.manager.playbackCoordinator.isPaused)
    }

    private func makeHarness() -> TTSManagerLifecycleHarness {
        let suiteName = "TTSManagerLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let replayCache = TTSReplayCache()
        replayCache.clear()

        let engine = SpyTTSEngine()
        let manager = TTSManager(
            settingsStore: AppSettingsStore(defaults: defaults),
            appHaptics: StubAppHaptics(),
            keyboardBridge: KeyVoxKeyboardBridge(),
            engine: engine,
            playbackCoordinator: TTSPlaybackCoordinator(),
            purchaseGate: StubTTSPurchaseGate(),
            replayCache: replayCache
        )

        return TTSManagerLifecycleHarness(
            defaults: defaults,
            suiteName: suiteName,
            replayCache: replayCache,
            engine: engine,
            manager: manager
        )
    }

    private func makeRequest(createdAt: TimeInterval) -> KeyVox_iOS.KeyVoxTTSRequest {
        KeyVox_iOS.KeyVoxTTSRequest(
            id: UUID(),
            text: "Lifecycle testing request",
            createdAt: createdAt,
            sourceSurface: KeyVox_iOS.KeyVoxTTSRequestSourceSurface.app,
            voiceID: AppSettingsStore.TTSVoice.alba.rawValue,
            kind: KeyVox_iOS.KeyVoxTTSRequestKind.speakClipboardText
        )
    }

    private func settleLifecycleTasks() async {
        await Task.yield()
        await Task.yield()
    }

    private func armPlaybackCoordinatorForPause(_ playbackCoordinator: TTSPlaybackCoordinator) {
        playbackCoordinator.fastModeEnabled = true
        playbackCoordinator.didStartPlayback = true
        playbackCoordinator.isPaused = false
        playbackCoordinator.isReplayingCachedAudio = false
        playbackCoordinator.playbackSessionID = UUID()
        playbackCoordinator.configureAudioGraphIfNeeded()
        let samples = Array(repeating: Float(0), count: 24_000)
        if let buffer = playbackCoordinator.makeBuffer(from: samples) {
            try? playbackCoordinator.configureAudioSession()
            try? playbackCoordinator.audioEngine.start()
            playbackCoordinator.scheduleBuffer(
                buffer,
                chunkDebugID: "test-buffer",
                chunkIndex: nil
            )
        }
        playbackCoordinator.playerNode.play()
    }
}

@MainActor
private struct TTSManagerLifecycleHarness {
    let defaults: UserDefaults
    let suiteName: String
    let replayCache: TTSReplayCache
    let engine: SpyTTSEngine
    let manager: TTSManager

    func cleanup() {
        manager.endBackgroundTaskIfNeeded()
        manager.playbackCoordinator.playerNode.stop()
        manager.playbackCoordinator.audioEngine.stop()
        replayCache.clear()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class SpyTTSEngine: TTSEngine {
    private(set) var immediateForegroundRequestCount = 0
    private(set) var immediateBackgroundRequestCount = 0
    private(set) var prepareForegroundCallCount = 0
    private(set) var prepareBackgroundCallCount = 0

    func prepareIfNeeded() async throws {}

    func prewarmVoiceIfNeeded(voiceID: String) async throws {}

    func requestForegroundSynthesisImmediately() {
        immediateForegroundRequestCount += 1
    }

    func requestBackgroundContinuationImmediately() {
        immediateBackgroundRequestCount += 1
    }

    func prepareForForegroundSynthesis() async {
        prepareForegroundCallCount += 1
    }

    func prepareForBackgroundContinuation() async {
        prepareBackgroundCallCount += 1
    }

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

private struct StubAppHaptics: AppHapticsEmitting {
    func emit(_ event: AppHapticEvent) {}
    func light() {}
    func medium() {}
    func selection() {}
    func success() {}
    func warning() {}
}

private final class StubTTSPurchaseGate: TTSPurchaseGating {
    var isTTSUnlocked = true
    var remainingFreeTTSSpeaksToday = 2
    var canStartNewTTSSpeak = true

    func refreshUsageIfNeeded() {}
    func presentUnlockSheet() {}
    func dismissUnlockSheet() {}
    func consumeFreeTTSSpeakIfNeeded() {}
}
