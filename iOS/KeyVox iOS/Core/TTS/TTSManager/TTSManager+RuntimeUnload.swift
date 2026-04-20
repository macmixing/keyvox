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

    func scheduleRuntimeUnloadAfterPlayback(reason: TTSRuntimeUnloadReason) {
        runtimeUnloadTask?.cancel()
        runtimeUnloadTask = nil
        pendingRuntimeUnloadReason = nil

        guard let delay = settingsStore.speakTimeoutTiming.unloadDelay else {
            unloadRuntimeImmediately(reason: reason)
            return
        }

        guard engine.isPreparedForSynthesis else {
            Self.log("Skipping PocketTTS runtime unload scheduling reason=\(reason.rawValue) because runtime is not warm.")
            return
        }

        pendingRuntimeUnloadReason = reason
        Self.log(
            "Scheduling PocketTTS runtime unload reason=\(reason.rawValue) delaySeconds=\(String(format: "%.0f", delay))."
        )
        runtimeUnloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard Task.isCancelled == false else { return }
            self?.runtimeUnloadTask = nil
            self?.pendingRuntimeUnloadReason = nil
            self?.unloadRuntimeImmediately(reason: .speakTimeoutExpired)
        }
    }

    func cancelScheduledRuntimeUnload(reason: String) {
        guard runtimeUnloadTask != nil else { return }

        Self.log("Canceling scheduled PocketTTS runtime unload reason=\(reason).")
        runtimeUnloadTask?.cancel()
        runtimeUnloadTask = nil
        pendingRuntimeUnloadReason = nil
    }

    func unloadRuntimeImmediately(reason: TTSRuntimeUnloadReason) {
        runtimeUnloadTask?.cancel()
        runtimeUnloadTask = nil
        pendingRuntimeUnloadReason = nil

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

        scheduleRuntimeUnloadAfterPlayback(reason: pendingRuntimeUnloadReason)
    }
}
