import SwiftUI

struct KeyVoxSpeakInstallCardView: View {
    static let installStepCount = 1

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject private var settingsStore: AppSettingsStore

    let showsUnlockDetails: Bool
    let purchaseSummaryText: String
    let revealedStepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.4))
                        .frame(width: 34, height: 34)

                    Image(systemName: pocketTTSReadyForAlba ? "checkmark" : "arrow.down.circle.fill")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Set Up Alba")
                        .font(.appFont(17, variant: .medium))
                        .foregroundStyle(.white)

                    Text("Install Alba and KeyVox will handle the PocketTTS engine automatically.")
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                installRow
                    .opacity(revealedStepCount > 0 ? 1 : 0)
                    .offset(y: revealedStepCount > 0 ? 0 : 10)
                    .allowsHitTesting(revealedStepCount > 0)
                    .accessibilityHidden(revealedStepCount == 0)
            }

            if showsUnlockDetails {
                unlockSummaryRow
                    .opacity(revealedStepCount == Self.installStepCount ? 1 : 0)
                    .allowsHitTesting(revealedStepCount == Self.installStepCount)
                    .accessibilityHidden(revealedStepCount != Self.installStepCount)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var sharedModelState: PocketTTSInstallState {
        pocketTTSModelManager.sharedModelInstallState
    }

    private var albaVoiceState: PocketTTSInstallState {
        pocketTTSModelManager.installState(for: .alba)
    }

    private var isSharedModelReady: Bool {
        if case .ready = sharedModelState {
            return true
        }
        return false
    }

    private var pocketTTSReadyForAlba: Bool {
        if case .ready = sharedModelState,
           case .ready = albaVoiceState {
            return true
        }
        return false
    }

    private var activeInstallState: PocketTTSInstallState? {
        if isSharedModelReady == false {
            switch sharedModelState {
            case .downloading, .installing:
                return sharedModelState
            case .notInstalled, .failed, .ready:
                break
            }
        }

        switch albaVoiceState {
        case .downloading, .installing:
            return albaVoiceState
        case .notInstalled, .failed, .ready:
            return nil
        }
    }

    private var installRow: some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(pocketTTSReadyForAlba ? Color.green : AppTheme.accent.opacity(0.32))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if pocketTTSReadyForAlba {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(.black)
                            } else {
                                Text("1")
                                    .font(.appFont(12, variant: .medium))
                                    .foregroundStyle(.white)
                            }
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model + Voice")
                            .font(.appFont(15, variant: .medium))
                            .foregroundStyle(.white)

                        Text(installStatusText)
                            .font(.appFont(13, variant: .light))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let activeInstallState,
                   let percentageText = progressText(for: activeInstallState) {
                    Text(percentageText)
                        .font(.appFont(13, variant: .medium))
                        .foregroundStyle(.yellow)
                } else if let buttonTitle = actionTitle {
                    AppActionButton(
                        title: buttonTitle,
                        style: .primary,
                        size: .compact,
                        fontSize: 14,
                        isEnabled: isActionEnabled,
                        action: {
                            appHaptics.light()
                            performAction()
                        }
                    )
                }
            }

            downloadProgressView

            if let errorText {
                Text(errorText)
                    .font(.appFont(12))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                .fill(AppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                        .stroke(AppTheme.rowStroke, lineWidth: 1)
                )
        )
    }

    private var unlockSummaryRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.yellow)

            Text(purchaseSummaryText)
                .font(.appFont(13, variant: .light))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var downloadProgressView: some View {
        switch activeInstallState {
        case .downloading(let progress), .installing(let progress):
            ModelDownloadProgress(progress: progress, showLabel: false)
        case .failed, .notInstalled, .ready, .none:
            EmptyView()
        }
    }

    private func progressText(for state: PocketTTSInstallState) -> String? {
        switch state {
        case .downloading(let progress), .installing(let progress):
            return "\(Int(progress * 100))%"
        case .notInstalled, .ready, .failed:
            return nil
        }
    }

    private var actionTitle: String? {
        if pocketTTSReadyForAlba {
            return nil
        }

        if case .failed = sharedModelState {
            return "Repair"
        }

        if case .failed = albaVoiceState {
            return "Repair"
        }

        if activeInstallState != nil {
            return nil
        }

        return "Install"
    }

    private var isActionEnabled: Bool {
        pocketTTSModelManager.isBusyInstallingAnotherTarget(voice: .alba) == false
            && pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true) == false
    }

    private var installStatusText: String {
        if pocketTTSReadyForAlba {
            return "Alba is installed, selected, and ready for KeyVox Speak."
        }

        switch sharedModelState {
        case .notInstalled:
            return "Install Alba and KeyVox will download PocketTTS first, then the Alba voice (~661 MB total)."
        case .downloading:
            return "Downloading the PocketTTS engine before installing Alba."
        case .installing:
            return "Installing the PocketTTS engine before Alba."
        case .ready:
            switch albaVoiceState {
            case .notInstalled:
                return "PocketTTS is ready. KeyVox will finish by installing Alba (~19 MB)."
            case .downloading:
                return "Downloading Alba."
            case .installing:
                return "Installing Alba."
            case .ready:
                return "Alba is installed, selected, and ready for KeyVox Speak."
            case .failed:
                return "Alba needs repair."
            }
        case .failed:
            return "PocketTTS setup needs repair before Alba can finish installing."
        }
    }

    private var errorText: String? {
        if case .failed(let message) = sharedModelState {
            return message
        }

        if case .failed(let message) = albaVoiceState {
            return message
        }

        return nil
    }

    private func performAction() {
        if settingsStore.ttsVoice != .alba {
            settingsStore.ttsVoice = .alba
        }

        if case .failed = sharedModelState {
            pocketTTSModelManager.repairVoiceEnsuringSharedModel(.alba)
            return
        }

        if case .failed = albaVoiceState {
            pocketTTSModelManager.repairVoiceEnsuringSharedModel(.alba)
            return
        }

        guard pocketTTSReadyForAlba == false else { return }
        pocketTTSModelManager.installVoiceEnsuringSharedModel(.alba)
    }
}
