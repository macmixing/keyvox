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

    @Test func defaultSpeakTimeoutKeepsRuntimeWarmForFiveMinutes() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        #expect(harness.manager.settingsStore.speakTimeoutTiming == .fiveMinutes)
    }

    @Test func replayablePlaybackReadyUnloadsTTSEngineWhenSpeakTimeoutIsImmediate() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.speakTimeoutTiming = .immediately
        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 5)

        harness.manager.handleReplayablePlaybackReady()

        #expect(harness.engine.unloadCallCount == 1)
    }

    @Test func replayablePlaybackReadyRetainsTTSEngineWhenSpeakTimeoutIsTimed() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 6)

        harness.manager.handleReplayablePlaybackReady()

        #expect(harness.engine.unloadCallCount == 0)
        #expect(harness.engine.isPreparedForSynthesis)
    }

    @Test func stopPlaybackSchedulesTTSEngineUnloadWhenSpeakTimeoutIsTimed() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 7)

        await harness.manager.stopPlayback()

        #expect(harness.engine.unloadCallCount == 0)
        #expect(harness.manager.runtimeUnloadTask != nil)
        #expect(harness.manager.pendingRuntimeUnloadReason == .stopPlayback)
    }

    @Test func stopPlaybackUnloadsTTSEngineWhenSpeakTimeoutIsImmediate() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.speakTimeoutTiming = .immediately
        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 8)

        await harness.manager.stopPlayback()

        #expect(harness.engine.unloadCallCount == 1)
    }

    @Test func stopPlaybackRetainsTTSEngineWhenSpeakTimeoutIsNever() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.speakTimeoutTiming = .never
        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 9)

        await harness.manager.stopPlayback()

        #expect(harness.engine.unloadCallCount == 0)
        #expect(harness.manager.runtimeUnloadTask == nil)
        #expect(harness.engine.isPreparedForSynthesis)
    }

    @Test func changingFromNeverToTimedSchedulesTTSEngineUnloadImmediately() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.settingsStore.speakTimeoutTiming = .never
        harness.engine.isPreparedForSynthesis = true

        harness.manager.settingsStore.speakTimeoutTiming = .fiveMinutes

        #expect(harness.engine.unloadCallCount == 0)
        #expect(harness.manager.runtimeUnloadTask != nil)
        #expect(harness.manager.pendingRuntimeUnloadReason == .settingChangedToTimed)
    }

    @Test func changingFromTimedToNeverCancelsPendingTTSEngineUnload() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 10)

        await harness.manager.stopPlayback()
        #expect(harness.manager.runtimeUnloadTask != nil)

        harness.manager.settingsStore.speakTimeoutTiming = .never

        #expect(harness.manager.runtimeUnloadTask == nil)
        #expect(harness.manager.pendingRuntimeUnloadReason == nil)
        #expect(harness.engine.isPreparedForSynthesis)
    }

    @Test func playbackErrorSchedulesTTSEngineUnloadWhenSpeakTimeoutIsTimed() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.engine.isPreparedForSynthesis = true
        harness.manager.activeRequest = makeRequest(createdAt: 11)

        harness.manager.handleError("synthetic failure")
        await settleLifecycleTasks()

        #expect(harness.engine.unloadCallCount == 0)
        #expect(harness.manager.runtimeUnloadTask != nil)
    }

    @Test func warmRuntimeStartMarksCurrentPlaybackWarm() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.engine.isPreparedForSynthesis = true
        harness.engine.keepsAudioStreamOpen = true

        await harness.manager.startPlayback(makeRequest(createdAt: 12))

        #expect(harness.manager.isCurrentPlaybackWarmStart)
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
        manager.cancelScheduledRuntimeUnload(logContext: "testCleanup")
        engine.finishPendingStream()
        manager.endBackgroundTaskIfNeeded()
        manager.playbackCoordinator.playerNode.stop()
        manager.playbackCoordinator.audioEngine.stop()
        replayCache.clear()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class SpyTTSEngine: TTSEngine {
    var isPreparedForSynthesis = false
    var keepsAudioStreamOpen = false
    private(set) var immediateForegroundRequestCount = 0
    private(set) var immediateBackgroundRequestCount = 0
    private(set) var prepareForegroundCallCount = 0
    private(set) var prepareBackgroundCallCount = 0
    private(set) var unloadCallCount = 0
    private var pendingStreamContinuation: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>.Continuation?

    func prepareIfNeeded() async throws {
        isPreparedForSynthesis = true
    }

    func prewarmVoiceIfNeeded(voiceID: String) async throws {}

    func unloadIfNeeded() {
        unloadCallCount += 1
        isPreparedForSynthesis = false
    }

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
            if keepsAudioStreamOpen == false {
                continuation.finish()
            } else {
                finishPendingStream()
                pendingStreamContinuation = continuation
            }
        }
    }

    func finishPendingStream() {
        pendingStreamContinuation?.finish()
        pendingStreamContinuation = nil
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
