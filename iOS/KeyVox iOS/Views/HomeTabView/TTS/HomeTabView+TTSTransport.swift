import Foundation
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
        String(localized: "Wait for the blue/green check mark before leaving.", comment: "Warning on the Home tab Speak Copied Text card during fast playback, telling the user not to leave the app until the check mark appears.")
    }

    var ttsStatusText: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .notInstalled:
                return String(localized: "Download the KeyVox Speak engine and Theo's voice (\(ApproximateDownloadSize.speakEngineAndVoice)) to speak copied text.", comment: "Status on the Home tab Speak Copied Text card before anything is installed. KeyVox Speak is a brand name and stays in English. Theo is a voice name and stays in English. The value in parentheses is the approximate download size.")
            case .downloading:
                return String(localized: "Downloading KeyVox Speak engine...", comment: "Status on the Home tab Speak Copied Text card while the text-to-speech engine downloads. KeyVox Speak is a brand name and stays in English.")
            case .installing:
                return String(localized: "Installing KeyVox Speak engine...", comment: "Status on the Home tab Speak Copied Text card while the text-to-speech engine installs. KeyVox Speak is a brand name and stays in English.")
            case .failed:
                return String(localized: "KeyVox Speak engine install failed.", comment: "Status on the Home tab Speak Copied Text card when the text-to-speech engine failed to install. KeyVox Speak is a brand name and stays in English.")
            case .ready:
                break
            }
        }

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            return String(localized: "Download \(effectiveTTSVoice.displayName)'s voice (\(ApproximateDownloadSize.speakVoice)) to speak copied text.", comment: "Status on the Home tab Speak Copied Text card when the selected voice is not installed. The first placeholder is the voice name, which stays in English; the second, in parentheses, is the approximate download size.")
        case .downloading:
            return String(localized: "Downloading \(effectiveTTSVoice.displayName)'s voice...", comment: "Status on the Home tab Speak Copied Text card while a voice downloads. The placeholder is the voice name, which stays in English.")
        case .installing:
            return String(localized: "Installing \(effectiveTTSVoice.displayName)'s voice...", comment: "Status on the Home tab Speak Copied Text card while a voice installs. The placeholder is the voice name, which stays in English.")
        case .failed:
            return String(localized: "\(effectiveTTSVoice.displayName) voice install failed.", comment: "Status on the Home tab Speak Copied Text card when a voice failed to install. The placeholder is the voice name, which stays in English.")
        case .ready:
            break
        }

        switch ttsManager.state {
        case .idle:
            if ttsPurchaseController.canStartNewTTSSpeak == false {
                if ttsPurchaseController.remainingFreeTTSSpeaksToday == 0 {
                    return String(localized: "Unlock Speak Unlimited to keep speaking copied text.", comment: "Status on the Home tab Speak Copied Text card when the free daily limit is used up. Speak Unlimited is the purchase name; Speak is a brand name and stays in English.")
                }
            }

            if ttsPurchaseController.isTTSUnlocked == false {
                let remainingFreeSpeaks = ttsPurchaseController.remainingFreeTTSSpeaksToday
                return String(localized: "\(remainingFreeSpeaks) free speaks left today.", comment: "Status on the Home tab Speak Copied Text card showing how many free uses are left today. %lld is the number left; use plural forms.")
            }
            return String(localized: "Speak copied text using your selected voice.", comment: "Status on the Home tab Speak Copied Text card when it is ready to read aloud.")
        case .preparing:
            return String(localized: "Getting ready...", comment: "Status on the Home tab Speak Copied Text card while playback is being prepared.")
        case .generating:
            return String(localized: "KeyVox is preparing to speak...", comment: "Status on the Home tab Speak Copied Text card while audio is being generated. KeyVox is a brand name and stays in English.")
        case .playing:
            return ttsManager.isPlaybackPaused
                ? String(localized: "Playback paused.", comment: "Status on the Home tab Speak Copied Text card while reading aloud is paused.")
                : String(localized: "Speaking copied text.", comment: "Status on the Home tab Speak Copied Text card while copied text is being read aloud.")
        case .finished:
            return String(localized: "Finished speaking.", comment: "Status on the Home tab Speak Copied Text card after reading aloud finished.")
        case .error:
            return String(localized: "Failed to speak.", comment: "Status on the Home tab Speak Copied Text card when reading aloud failed.")
        }
    }

    var ttsErrorText: String? {
        guard let lastErrorMessage = ttsManager.lastErrorMessage else { return nil }

        if lastErrorMessage.localizedCaseInsensitiveContains("unable to compute the prediction using a neural network model")
            || lastErrorMessage.localizedCaseInsensitiveContains("broken/unsupported model")
            || lastErrorMessage.localizedCaseInsensitiveContains("error code -1") {
            return String(localized: "Speaking could not continue after the app moved to the background.", comment: "Error on the Home tab Speak Copied Text card when reading aloud stopped because the user left the app.")
        }

        return lastErrorMessage
    }
}
