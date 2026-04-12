import SwiftUI

struct KeyVoxSpeakInstallCardView: View {
    static let installStepCount = 1
    private static let featuredVoice = AppSettingsStore.TTSVoice.alba

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject private var settingsStore: AppSettingsStore

    let revealedStepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.4))
                        .frame(width: 34, height: 34)

                    if pocketTTSReadyForAlba {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 15, weight: .heavy))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.green, .yellow)
                            .offset(x: 3)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.yellow)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Set Up \(Self.featuredVoice.displayName)")
                        .font(.appFont(17, variant: .medium))
                        .foregroundStyle(.white)

                    Text("Install \(Self.featuredVoice.displayName)'s voice and KeyVox will handle the Speak engine for you.")
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
                        .overlay(Circle().stroke(pocketTTSReadyForAlba ? Color.green : Color.yellow, lineWidth: 0.4))
                        .overlay {
                            if pocketTTSReadyForAlba {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.black)
                            } else {
                                Image(systemName: "arrowshape.down.fill")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(.yellow)
                            }
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model + Voice")
                            .font(.appFont(15, variant: .medium))
                            .foregroundStyle(.white)

                        (Text(installStatusText)
                            .foregroundStyle(.white.opacity(0.62))
                        + Text(installSizeAnnotation ?? "")
                            .foregroundStyle(.yellow.opacity(0.72)))
                            .font(.appFont(13, variant: .light))
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

    private var installSizeAnnotation: String? {
        if pocketTTSReadyForAlba { return nil }

        if case .notInstalled = sharedModelState { return " (~661 MB total)." }

        if case .ready = sharedModelState,
           case .notInstalled = albaVoiceState { return " (~19 MB)." }

        return nil
    }

    private var installStatusText: String {
        if pocketTTSReadyForAlba {
            return "\(Self.featuredVoice.displayName)'s voice is installed, selected, and ready for KeyVox Speak."
        }

        switch sharedModelState {
        case .notInstalled:
            return "Install \(Self.featuredVoice.displayName) and KeyVox will download the Speak engine first, then \(Self.featuredVoice.displayName)'s voice"
        case .downloading:
            return "Downloading the Speak engine before installing \(Self.featuredVoice.displayName)."
        case .installing:
            return "Installing the Speak engine before \(Self.featuredVoice.displayName)."
        case .ready:
            switch albaVoiceState {
            case .notInstalled:
                return "KeyVox Speak engine is ready. Now we'll finish by installing \(Self.featuredVoice.displayName)'s voice."
            case .downloading:
                return "Downloading \(Self.featuredVoice.displayName)."
            case .installing:
                return "Installing \(Self.featuredVoice.displayName)."
            case .ready:
                return "\(Self.featuredVoice.displayName) is installed, selected, and ready for KeyVox Speak."
            case .failed:
                return "\(Self.featuredVoice.displayName) needs repair."
            }
        case .failed:
            return "Speak engine setup needs repair before \(Self.featuredVoice.displayName) can finish installing."
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
