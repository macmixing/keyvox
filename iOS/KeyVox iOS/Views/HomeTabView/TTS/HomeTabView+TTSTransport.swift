import SwiftUI

extension HomeTabView {
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

    var ttsStatusText: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .notInstalled:
                return "Install PocketTTS CoreML to read copied text aloud."
            case .downloading:
                return "Downloading PocketTTS CoreML..."
            case .installing:
                return "Installing PocketTTS CoreML..."
            case .failed:
                return "PocketTTS CoreML install failed."
            case .ready:
                break
            }
        }

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            return "Install the \(effectiveTTSVoice.displayName) voice to read copied text aloud."
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
            if ttsPurchaseController.isTTSUnlocked == false {
                if ttsPurchaseController.remainingFreeTTSSpeaksToday == 0 {
                    return "Unlock TTS to keep speaking copied text."
                }

                let remainingFreeSpeaks = ttsPurchaseController.remainingFreeTTSSpeaksToday
                let noun = remainingFreeSpeaks == 1 ? "speak" : "speaks"
                return "\(remainingFreeSpeaks) free \(noun) left today."
            }
            return "Read copied text aloud using your selected voice."
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
            return "Playback could not continue after the app moved to the background."
        }

        return lastErrorMessage
    }
}
