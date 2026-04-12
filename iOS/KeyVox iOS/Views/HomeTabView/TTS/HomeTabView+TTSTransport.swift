import SwiftUI

extension HomeTabView {
    var showsTTSCellularDownloadWarning: Bool {
        InlineWarningRules.showsHomeTTSCellularDownloadWarning(
            isOnCellular: downloadNetworkMonitor.isOnCellular,
            sharedModelState: pocketTTSModelManager.sharedModelInstallState
        )
    }

    var ttsCellularDownloadWarningText: String {
        InlineWarningRow.Copy.cellularDownloadRecommended
    }

    var ttsWarningText: String? {
        if showsFastModeBackgroundSafetyWarning {
            return fastModeBackgroundSafetyWarningText
        }

        guard let warningMessage = ttsManager.warningMessage else { return nil }

        switch ttsManager.state {
        case .idle, .finished, .error:
            return warningMessage
        case .preparing, .generating, .playing:
            return nil
        }
    }

    var ttsTransportButton: some View {
        Button(action: handleSecondaryTTSAction) {
            ZStack {
                Circle()
                    .fill(Color.yellow)

                Circle()
                    .trim(from: 0, to: ttsTransportPlaybackProgress)
                    .stroke(
                        Color.indigo,
                        style: StrokeStyle(lineWidth: 4, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                    .opacity(showsTTSTransportProgressRing ? 1 : 0)

                Image(systemName: ttsTransportSymbolName)
                    .font(.system(size: 22, weight: ttsTransportSymbolWeight))
                    .foregroundStyle(.black)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ttsTransportBadgeColor)
                    .background(Circle().fill(Color.black))
                    .offset(x: 3, y: -1)
                    .opacity(showsTTSTransportBadge ? 1 : 0)
                    .scaleEffect(showsTTSTransportBadge ? 1 : 0.82)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .yellow.opacity(0.3), radius: 10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.22), value: showsTTSTransportBadge)
    }

    var showsTTSTransportButton: Bool {
        if ttsManager.state == .preparing || ttsManager.state == .generating {
            return false
        }

        return ttsManager.isActive || ttsManager.hasReplayablePlayback
    }

    var showsBackgroundSafeCheckmark: Bool {
        guard ttsManager.state == .playing, !ttsManager.isReplayingCachedPlayback else {
            return false
        }

        if settingsStore.fastPlaybackModeEnabled {
            return ttsManager.isFastModeBackgroundSafe
        }

        return true
    }

    var showsReplayReadyCheckmark: Bool {
        ttsManager.isCurrentRequestReplayReady
            && ttsManager.isActive
            && !ttsManager.isReplayingCachedPlayback
    }

    var showsTTSTransportBadge: Bool {
        showsReplayReadyCheckmark || showsBackgroundSafeCheckmark
    }

    var ttsTransportBadgeColor: Color {
        if showsReplayReadyCheckmark {
            return .green
        }
        return .blue
    }

    var showsTTSTransportProgressRing: Bool {
        ttsManager.state == .playing && !ttsManager.isReplayingCachedPlayback
    }

    var ttsTransportPlaybackProgress: CGFloat {
        CGFloat(min(1, max(0, ttsManager.playbackProgress)))
    }

    var ttsTransportSymbolName: String {
        if ttsManager.isPlaybackPaused {
            return "play.fill"
        }
        if ttsManager.state == .playing {
            return "pause.fill"
        }
        return "repeat"
    }

    var ttsTransportSymbolWeight: Font.Weight {
        .medium
    }

    var showsReplayScrubber: Bool {
        ttsManager.isReplayingCachedPlayback
    }

    var showsFastModeBackgroundSafetyWarning: Bool {
        settingsStore.fastPlaybackModeEnabled
            && ttsManager.state == .playing
            && ttsManager.isPlaybackPaused == false
            && ttsManager.isReplayingCachedPlayback == false
            && hasReachedFastModeBackgroundSafeStateThisPlayback == false
            && ttsManager.isFastModeBackgroundSafe == false
    }

    var fastModeBackgroundSafetyWarningText: String {
        "Wait for the blue/green check mark before leaving."
    }

    var ttsStatusText: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .notInstalled:
                return "Install the KeyVox Speak engine to speak copied text."
            case .downloading:
                return "Downloading KeyVox Speak engine..."
            case .installing:
                return "Installing KeyVox Speak engine..."
            case .failed:
                return "KeyVox Speak engine install failed."
            case .ready:
                break
            }
        }

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            return "Install the \(effectiveTTSVoice.displayName) voice to speak copied text."
        case .downloading:
            return "Downloading the \(effectiveTTSVoice.displayName) voice..."
        case .installing:
            return "Installing the \(effectiveTTSVoice.displayName) voice..."
        case .failed:
            return "\(effectiveTTSVoice.displayName) voice install failed."
        case .ready:
            break
        }

        switch ttsManager.state {
        case .idle:
            if ttsPurchaseController.canStartNewTTSSpeak == false {
                if ttsPurchaseController.remainingFreeTTSSpeaksToday == 0 {
                    return "Unlock Speak Unlimited to keep speaking copied text."
                }
            }

            if ttsPurchaseController.isTTSUnlocked == false {
                let remainingFreeSpeaks = ttsPurchaseController.remainingFreeTTSSpeaksToday
                let noun = remainingFreeSpeaks == 1 ? "speak" : "speaks"
                return "\(remainingFreeSpeaks) free \(noun) left today."
            }
            return "Speak copied text using your selected voice."
        case .preparing:
            return "Getting ready..."
        case .generating:
            return "KeyVox is preparing to speak..."
        case .playing:
            return ttsManager.isPlaybackPaused ? "Playback paused." : "Speaking copied text."
        case .finished:
            return "Finished speaking."
        case .error:
            return "Failed to speak."
        }
    }

    var ttsErrorText: String? {
        guard let lastErrorMessage = ttsManager.lastErrorMessage else { return nil }

        if lastErrorMessage.localizedCaseInsensitiveContains("unable to compute the prediction using a neural network model")
            || lastErrorMessage.localizedCaseInsensitiveContains("broken/unsupported model")
            || lastErrorMessage.localizedCaseInsensitiveContains("error code -1") {
            return "Speaking could not continue after the app moved to the background."
        }

        return lastErrorMessage
    }
}
