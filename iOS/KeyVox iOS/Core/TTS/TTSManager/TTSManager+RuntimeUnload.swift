import Foundation

enum TTSRuntimeUnloadReason: String {
    case assetInvalidated
    case memoryWarning
    case playbackError
    case playbackFinished
    case replayableAudioReady
    case settingChangedToImmediate
    case speakTimeoutExpired
    case stopPlayback
}

extension TTSManager {
    func releaseRuntimeWhenReplayableAudioIsReady() {
        guard settingsStore.speakTimeoutTiming == .immediately else {
            Self.log("Retaining PocketTTS runtime until playback ends because speakTimeout=\(settingsStore.speakTimeoutTiming.rawValue).")
            return
        }

        unloadRuntimeImmediately(reason: .replayableAudioReady)
    }

    func scheduleRuntimeUnloadAfterPlayback(
        reason: TTSRuntimeUnloadReason,
        startedAt: Date = Date()
    ) {
        runtimeUnloadTask?.cancel()
        runtimeUnloadTask = nil
        pendingRuntimeUnloadReason = nil
        pendingRuntimeUnloadStartedAt = nil

        guard let delay = settingsStore.speakTimeoutTiming.unloadDelay else {
            unloadRuntimeImmediately(reason: reason)
            return
        }

        guard engine.isPreparedForSynthesis else {
            Self.log("Skipping PocketTTS runtime unload scheduling reason=\(reason.rawValue) because runtime is not warm.")
            return
        }

        let elapsedTime = max(0, Date().timeIntervalSince(startedAt))
        let remainingDelay = max(0, delay - elapsedTime)
        guard remainingDelay > 0 else {
            unloadRuntimeImmediately(reason: .speakTimeoutExpired)
            return
        }

        pendingRuntimeUnloadReason = reason
        pendingRuntimeUnloadStartedAt = startedAt
        Self.log(
            "Scheduling PocketTTS runtime unload reason=\(reason.rawValue) delaySeconds=\(String(format: "%.0f", remainingDelay))."
        )
        runtimeUnloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
            guard Task.isCancelled == false else { return }
            self?.unloadRuntimeImmediately(reason: .speakTimeoutExpired)
        }
    }

    func cancelScheduledRuntimeUnload(logContext: String) {
        guard runtimeUnloadTask != nil else { return }

        Self.log("Canceling scheduled PocketTTS runtime unload context=\(logContext).")
        runtimeUnloadTask?.cancel()
        runtimeUnloadTask = nil
        pendingRuntimeUnloadReason = nil
        pendingRuntimeUnloadStartedAt = nil
    }

    func unloadRuntimeImmediately(reason: TTSRuntimeUnloadReason) {
        runtimeUnloadTask?.cancel()
        runtimeUnloadTask = nil
        pendingRuntimeUnloadReason = nil
        pendingRuntimeUnloadStartedAt = nil

        guard engine.isPreparedForSynthesis else {
            Self.log("Skipping PocketTTS runtime unload reason=\(reason.rawValue) because runtime is not warm.")
            return
        }

        Self.log("Unloading PocketTTS runtime reason=\(reason.rawValue).")
        engine.unloadIfNeeded()
    }

    func handleSpeakTimeoutTimingChanged() {
        guard let pendingRuntimeUnloadReason else {
            if settingsStore.speakTimeoutTiming == .immediately, isActive == false {
                unloadRuntimeImmediately(reason: .settingChangedToImmediate)
            }
            return
        }

        guard settingsStore.speakTimeoutTiming.unloadDelay != nil else {
            unloadRuntimeImmediately(reason: .settingChangedToImmediate)
            return
        }

        scheduleRuntimeUnloadAfterPlayback(
            reason: pendingRuntimeUnloadReason,
            startedAt: pendingRuntimeUnloadStartedAt ?? Date()
        )
    }
}
