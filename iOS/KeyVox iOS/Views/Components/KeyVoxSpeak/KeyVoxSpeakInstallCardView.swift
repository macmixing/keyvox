import SwiftUI

struct KeyVoxSpeakInstallCardView: View {
    fileprivate enum InstallStep: Int, CaseIterable, Identifiable {
        case sharedModel
        case albaVoice

        var id: Int { rawValue }
    }

    static let installStepCount = InstallStep.allCases.count

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

                    Text("Download the PocketTTS engine and the Alba voice you heard on the first page.")
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                ForEach(Array(InstallStep.allCases.enumerated()), id: \.element) { index, step in
                    installStepRow(step)
                        .opacity(index < revealedStepCount ? 1 : 0)
                        .offset(y: index < revealedStepCount ? 0 : 10)
                }
            }

            if showsUnlockDetails {
                unlockSummaryRow
                    .opacity(revealedStepCount == Self.installStepCount ? 1 : 0)
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

    private func installState(for step: InstallStep) -> PocketTTSInstallState {
        switch step {
        case .sharedModel:
            return sharedModelState
        case .albaVoice:
            return albaVoiceState
        }
    }

    private func installStepRow(_ step: InstallStep) -> some View {
        let state = installState(for: step)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(step.isReady(in: pocketTTSModelManager) ? Color.green : AppTheme.accent.opacity(0.32))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if step.isReady(in: pocketTTSModelManager) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(.black)
                            } else {
                                Text("\(step.rawValue + 1)")
                                    .font(.appFont(12, variant: .medium))
                                    .foregroundStyle(.white)
                            }
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.appFont(15, variant: .medium))
                            .foregroundStyle(.white)

                        Text(step.statusText(in: pocketTTSModelManager))
                            .font(.appFont(13, variant: .light))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let percentageText = progressText(for: state) {
                    Text(percentageText)
                        .font(.appFont(13, variant: .medium))
                        .foregroundStyle(.yellow)
                } else if let buttonTitle = actionTitle(for: state) {
                    AppActionButton(
                        title: buttonTitle,
                        style: .primary,
                        size: .compact,
                        fontSize: 14,
                        isEnabled: actionEnabled(for: step),
                        action: {
                            appHaptics.light()
                            performAction(for: step, state: state)
                        }
                    )
                }
            }

            switch state {
            case .downloading(let progress), .installing(let progress):
                ModelDownloadProgress(progress: progress, showLabel: false)
            case .failed(let message):
                Text(message)
                    .font(.appFont(12))
                    .foregroundStyle(.red)
            case .notInstalled, .ready:
                EmptyView()
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

    private func progressText(for state: PocketTTSInstallState) -> String? {
        switch state {
        case .downloading(let progress), .installing(let progress):
            return "\(Int(progress * 100))%"
        case .notInstalled, .ready, .failed:
            return nil
        }
    }

    private func actionTitle(for state: PocketTTSInstallState) -> String? {
        switch state {
        case .notInstalled:
            return "Install"
        case .failed:
            return "Repair"
        case .downloading, .installing, .ready:
            return nil
        }
    }

    private func actionEnabled(for step: InstallStep) -> Bool {
        switch step {
        case .sharedModel:
            return pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true) == false
        case .albaVoice:
            return isSharedModelReady
                && pocketTTSModelManager.isBusyInstallingAnotherTarget(voice: .alba) == false
        }
    }

    private func performAction(for step: InstallStep, state: PocketTTSInstallState) {
        switch step {
        case .sharedModel:
            switch state {
            case .notInstalled:
                pocketTTSModelManager.downloadSharedModel()
            case .failed:
                pocketTTSModelManager.repairSharedModelIfNeeded()
            case .downloading, .installing, .ready:
                break
            }
        case .albaVoice:
            guard isSharedModelReady else { return }
            if settingsStore.ttsVoice != .alba {
                settingsStore.ttsVoice = .alba
            }
            switch state {
            case .notInstalled:
                pocketTTSModelManager.downloadVoice(.alba)
            case .failed:
                pocketTTSModelManager.repairVoiceIfNeeded(.alba)
            case .downloading, .installing, .ready:
                break
            }
        }
    }
}

fileprivate extension KeyVoxSpeakInstallCardView.InstallStep {
    var title: String {
        switch self {
        case .sharedModel:
            return "PocketTTS CoreML"
        case .albaVoice:
            return "Alba Voice"
        }
    }

    func isReady(in modelManager: PocketTTSModelManager) -> Bool {
        switch self {
        case .sharedModel:
            if case .ready = modelManager.sharedModelInstallState {
                return true
            }
            return false
        case .albaVoice:
            if case .ready = modelManager.installState(for: .alba) {
                return true
            }
            return false
        }
    }

    func statusText(in modelManager: PocketTTSModelManager) -> String {
        switch self {
        case .sharedModel:
            switch modelManager.sharedModelInstallState {
            case .notInstalled:
                return "Download the shared engine that powers KeyVox Speak (~642 MB)."
            case .downloading:
                return "Downloading the shared playback engine."
            case .installing:
                return "Installing the shared playback engine."
            case .ready:
                return "PocketTTS CoreML is ready."
            case .failed:
                return "The shared playback engine needs repair."
            }
        case .albaVoice:
            switch modelManager.installState(for: .alba) {
            case .notInstalled:
                if case .ready = modelManager.sharedModelInstallState {
                    return "Install Alba to match the preview voice from scene A (~19 MB)."
                }
                return "Install PocketTTS CoreML first, then download Alba (~19 MB)."
            case .downloading:
                return "Downloading Alba."
            case .installing:
                return "Installing Alba."
            case .ready:
                return "Alba is installed and selected."
            case .failed:
                return "Alba needs repair."
            }
        }
    }
}
