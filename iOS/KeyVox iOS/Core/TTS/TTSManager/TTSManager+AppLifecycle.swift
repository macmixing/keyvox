import AVFoundation
import Foundation
import UIKit

extension TTSManager {
    func requestFastModeBackgroundContinuationIfNeeded() {
        guard hasRequestedFastModeBackgroundContinuation == false else { return }
        hasRequestedFastModeBackgroundContinuation = true
        requestImmediateBackgroundContinuation()
    }

    private func requestImmediateForegroundSynthesis() {
        engine.requestForegroundSynthesisImmediately()
        Task {
            await engine.prepareForForegroundSynthesis()
        }
    }

    private func requestImmediateBackgroundContinuation() {
        engine.requestBackgroundContinuationImmediately()
        Task {
            await engine.prepareForBackgroundContinuation()
        }
    }

    func handleAppDidBecomeActive() {
        KeyVoxIPCBridge.touchHeartbeat()
        hasRequestedFastModeBackgroundContinuation = false
        requestImmediateForegroundSynthesis()
        playbackCoordinator.prepareForForegroundPlayback()
        endBackgroundTaskIfNeeded()
    }

    func handleAppWillResignActive() {
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
                requestFastModeBackgroundContinuationIfNeeded()
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
            requestImmediateBackgroundContinuation()
        }
        playbackCoordinator.prepareForBackgroundTransition()
    }

    func handleAppDidEnterBackground() {
        dismissPlaybackPreparationView()
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

    @objc
    func handleProtectedDataWillBecomeUnavailableNotification(_ notification: Notification) {
        let isActiveLiveGeneration =
            state == .playing
            && isPlaybackPaused == false
            && isReplayingCachedPlayback == false

        Self.log(
            "Protected data will become unavailable state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback) fastMode=\(settingsStore.fastPlaybackModeEnabled) backgroundSafe=\(isFastModeBackgroundSafe) isActiveLiveGeneration=\(isActiveLiveGeneration)"
        )

        guard isActiveLiveGeneration else { return }

        if settingsStore.fastPlaybackModeEnabled {
            guard playbackCoordinator.canContinueBackgroundPlaybackInFastMode else {
                if playbackCoordinator.canPausePlayback {
                    Self.log("Protected data will become unavailable while fast-mode playback is not background-safe; pausing playback.")
                    beginBackgroundTaskIfNeeded(force: true)
                    requestFastModeBackgroundContinuationIfNeeded()
                    pausePlayback()
                }
                return
            }
        }

        beginBackgroundTaskIfNeeded(force: true)
        if settingsStore.fastPlaybackModeEnabled {
            requestFastModeBackgroundContinuationIfNeeded()
        } else {
            requestImmediateBackgroundContinuation()
        }
    }

    @objc
    func handleProtectedDataDidBecomeAvailableNotification(_ notification: Notification) {
        Self.log(
            "Protected data did become available state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback)"
        )
    }

    @objc
    func handleAudioSessionInterruptionNotification(_ notification: Notification) {
        let typeDescription: String
        if let userInfo = notification.userInfo,
           let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
           let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) {
            switch interruptionType {
            case .began:
                typeDescription = "began"
            case .ended:
                typeDescription = "ended"
            @unknown default:
                typeDescription = "unknown(\(typeValue))"
            }
        } else {
            typeDescription = "missing"
        }

        let optionsDescription: String
        if let userInfo = notification.userInfo,
           let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
            optionsDescription = String(optionsValue)
        } else {
            optionsDescription = "nil"
        }

        Self.log(
            "Audio session interruption type=\(typeDescription) options=\(optionsDescription) state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback) pausedOffset=\(pausedReplaySampleOffset.map(String.init) ?? "nil")"
        )
    }

    @objc
    func handleAudioSessionRouteChangeNotification(_ notification: Notification) {
        let reasonDescription: String
        let routeChangeReason: AVAudioSession.RouteChangeReason?
        if let userInfo = notification.userInfo,
           let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
            routeChangeReason = reason
            switch reason {
            case .newDeviceAvailable:
                reasonDescription = "newDeviceAvailable"
            case .oldDeviceUnavailable:
                reasonDescription = "oldDeviceUnavailable"
            case .categoryChange:
                reasonDescription = "categoryChange"
            case .override:
                reasonDescription = "override"
            case .wakeFromSleep:
                reasonDescription = "wakeFromSleep"
            case .noSuitableRouteForCategory:
                reasonDescription = "noSuitableRouteForCategory"
            case .routeConfigurationChange:
                reasonDescription = "routeConfigurationChange"
            case .unknown:
                reasonDescription = "unknown"
            @unknown default:
                reasonDescription = "unknown(\(reasonValue))"
            }
        } else {
            routeChangeReason = nil
            reasonDescription = "missing"
        }

        Self.log(
            "Audio session route change reason=\(reasonDescription) state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback) pausedOffset=\(pausedReplaySampleOffset.map(String.init) ?? "nil") backgroundTaskActive=\(backgroundTaskID != .invalid)"
        )

        guard isReplayingCachedPlayback, isPlaybackPaused == false else { return }
        guard let routeChangeReason else { return }

        switch routeChangeReason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            let renderTimeAvailable = playbackCoordinator.playerNode.lastRenderTime != nil
            let playerSampleTimeDescription: String
            if let renderTime = playbackCoordinator.playerNode.lastRenderTime,
               let playerTime = playbackCoordinator.playerNode.playerTime(forNodeTime: renderTime) {
                playerSampleTimeDescription = String(playerTime.sampleTime)
            } else {
                playerSampleTimeDescription = "nil"
            }
            Self.log(
                "Replay route-change snapshot currentPlaybackOffset=\(playbackCoordinator.currentPlaybackSampleOffset) currentReplayOffset=\(playbackCoordinator.currentReplaySampleOffset()) replayStartOffset=\(playbackCoordinator.replayStartSampleOffset) replayPausedOffset=\(playbackCoordinator.replayPausedSampleOffset) queuedBuffers=\(playbackCoordinator.queuedBufferCount) queuedSamples=\(playbackCoordinator.queuedSampleCount) renderTimeAvailable=\(renderTimeAvailable) playerSampleTime=\(playerSampleTimeDescription)"
            )
            let liveReplayOffset = playbackCoordinator.currentReplaySampleOffset()
            let resumeBaseOffset = liveReplayOffset > 0
                ? liveReplayOffset
                : playbackCoordinator.replayStartSampleOffset
            let resumeOffset = min(
                max(0, resumeBaseOffset),
                max(0, playbackCoordinator.replayablePlaybackSampleCount - 1)
            )
            Self.log("Rebuilding active cached replay after route change from offset=\(resumeOffset)")
            if let lastReplayableRequest {
                activeRequest = lastReplayableRequest
            }
            hasStartedPlaybackForActiveRequest = true
            didEmitPreparationCompletionForActiveRequest = true
            isPlaybackPaused = false
            dismissPlaybackPreparationView()
            beginBackgroundTaskIfNeeded()
            playbackCoordinator.replayLastPlayback(startingAtSample: resumeOffset, shouldAutoplay: true)
        default:
            break
        }
    }
}
