import Foundation
import UIKit

extension TTSManager {
    func handleAppDidBecomeActive() {
        Self.log("handleAppDidBecomeActive state=\(state.rawValue) backgroundTaskActive=\(backgroundTaskID != .invalid)")
        KeyVoxIPCBridge.touchHeartbeat()
        Task {
            await engine.prepareForForegroundSynthesis()
        }
        playbackCoordinator.prepareForForegroundPlayback()
        endBackgroundTaskIfNeeded()
    }

    func handleAppWillResignActive() {
        Self.log("handleAppWillResignActive state=\(state.rawValue) hasStartedPlayback=\(hasStartedPlaybackForActiveRequest) fastMode=\(settingsStore.fastPlaybackModeEnabled)")
        guard isActive, (hasStartedPlaybackForActiveRequest || playbackPreparationPhase == .readyToReturn) else { return }

        if settingsStore.fastPlaybackModeEnabled {
            if isReplayingCachedPlayback {
                beginBackgroundTaskIfNeeded(force: true)
                playbackCoordinator.prepareForBackgroundTransition()
                Self.log("Fast Mode enabled: continuing cached replay in background.")
                return
            }
            if hasStartedPlaybackForActiveRequest {
                beginBackgroundTaskIfNeeded(force: true)
                Task {
                    await engine.prepareForBackgroundContinuation()
                }
                playbackCoordinator.prepareForBackgroundTransition()
            } else {
                endBackgroundTaskIfNeeded()
            }
            if playbackCoordinator.canContinueBackgroundPlaybackInFastMode {
                Self.log("Fast Mode enabled: continuing playback in background with sufficient queued runway")
            } else if playbackCoordinator.canPausePlayback {
                Self.log("Fast Mode enabled: pausing active playback because queued runway is insufficient for background continuation")
                pausePlayback()
            } else {
                Self.log("Fast Mode enabled: skipping background handoff before playback start")
            }
            return
        }

        beginBackgroundTaskIfNeeded()

        let shouldPreserveForegroundSynthesisDuringTransition =
            activeRequest?.sourceSurface == .keyboard && playbackPreparationPhase != .readyToReturn
        if shouldPreserveForegroundSynthesisDuringTransition {
            Self.log("Delaying background-safe synthesis switch until playback is ready to return.")
        } else {
            Task {
                await engine.prepareForBackgroundContinuation()
            }
        }
        playbackCoordinator.prepareForBackgroundTransition()
    }

    func handleAppDidEnterBackground() {
        Self.log("handleAppDidEnterBackground state=\(state.rawValue) backgroundTaskActive=\(backgroundTaskID != .invalid) fastMode=\(settingsStore.fastPlaybackModeEnabled)")
        isPlaybackPreparationViewPresented = false
        guard settingsStore.fastPlaybackModeEnabled == false else {
            if hasStartedPlaybackForActiveRequest {
                playbackCoordinator.didEnterBackground()
            } else {
                endBackgroundTaskIfNeeded()
            }
            return
        }
        beginBackgroundTaskIfNeeded()
        playbackCoordinator.didEnterBackground()
    }

    func beginBackgroundTaskIfNeeded(force: Bool = false) {
        guard TTSManagerPolicy.shouldBeginBackgroundTask(
            isActive: isActive,
            fastModeEnabled: settingsStore.fastPlaybackModeEnabled,
            force: force
        ) else {
            if force == false && settingsStore.fastPlaybackModeEnabled {
                Self.log("Skipping background task because Fast Mode is enabled.")
            }
            return
        }
        guard backgroundTaskID == .invalid else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "KeyVoxTTSPlayback") { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTaskIfNeeded()
            }
        }
        Self.log("beginBackgroundTask id=\(backgroundTaskID.rawValue)")
        scheduleBackgroundTaskRelease()
    }

    func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        Self.log("endBackgroundTask id=\(backgroundTaskID.rawValue)")
        backgroundTaskReleaseTask?.cancel()
        backgroundTaskReleaseTask = nil
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    func scheduleBackgroundTaskRelease() {
        backgroundTaskReleaseTask?.cancel()
        backgroundTaskReleaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: TTSManagerPolicy.continuationGracePeriodNanoseconds)
            self?.endBackgroundTaskIfNeeded()
        }
    }

    func updateIdleSleepPrevention() {
        UIApplication.shared.isIdleTimerDisabled = shouldPreventIdleSleep
    }
}
