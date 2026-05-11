import SwiftUI

struct SettingsVibesAIInstallCard: View {
    @Binding var triggerKeyInteractionsEnabled: Bool
    let installState: MacLocalRewriteModelInstallState
    let downloadAction: () -> Void
    let repairAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        SettingsCard {
            VStack(spacing: 16) {
                SettingsRow(
                    assetIcon: "vibes-logo",
                    title: SettingsVibesAIInstallCardCopy.cardTitle,
                    subtitle: subtitleText
                ) {
                    actionControl
                }

                Divider()
                    .background(Color.white.opacity(0.22))

                triggerKeyInteractionsToggle

                if shouldShowInstallContent {
                    Divider()
                        .background(Color.white.opacity(0.22))

                    installContent
                }
            }
        }
    }

    private var triggerKeyInteractionsToggle: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(SettingsVibesAIInstallCardCopy.triggerKeyInteractionsTitle)
                    .font(.appFont(14))
                    .foregroundStyle(.white)

                Text(SettingsVibesAIInstallCardCopy.triggerKeyInteractionsSubtitle)
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $triggerKeyInteractionsEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel(SettingsVibesAIInstallCardCopy.triggerKeyInteractionsAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var actionControl: some View {
        switch installState {
        case .notInstalled:
            AppActionButton(
                title: SettingsVibesAIInstallCardCopy.downloadAction,
                style: .primary,
                minWidth: 84,
                action: downloadAction
            )
        case .ready:
            AppActionButton(
                title: SettingsVibesAIInstallCardCopy.deleteAction,
                style: .destructive,
                minWidth: 84,
                action: deleteAction
            )
        case .failed:
            AppActionButton(
                title: SettingsVibesAIInstallCardCopy.repairAction,
                style: .primary,
                minWidth: 84,
                action: repairAction
            )
        case .downloading, .installing:
            EmptyView()
        }
    }

    private var installContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.appFont(10))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let progress {
                LabeledProgressBar(progress: progress, statusText: statusText)
            }
        }
    }

    private var subtitleText: String {
        switch installState {
        case .ready:
            return SettingsVibesAIInstallCardCopy.readyStatus
        case .notInstalled, .downloading, .installing, .failed:
            return SettingsVibesAIInstallCardCopy.downloadRequiredStatus
        }
    }

    private var statusText: String {
        switch installState {
        case .downloading:
            return SettingsVibesAIInstallCardCopy.downloadingStatus
        case .installing:
            return SettingsVibesAIInstallCardCopy.installingStatus
        case .failed:
            return SettingsVibesAIInstallCardCopy.installFailedStatus
        case .notInstalled, .ready:
            return ""
        }
    }

    private var progress: Double? {
        switch installState {
        case .downloading(let progress), .installing(let progress):
            return progress
        case .notInstalled, .ready, .failed:
            return nil
        }
    }

    private var errorMessage: String? {
        if case .failed(let message) = installState {
            return message
        }

        return nil
    }

    private var shouldShowInstallContent: Bool {
        switch installState {
        case .downloading, .installing, .failed:
            return true
        case .notInstalled, .ready:
            return false
        }
    }
}

enum SettingsVibesAIInstallCardCopy {
    static let cardTitle = "KeyVox Vibes AI"
    static let readyStatus = "KeyVox Vibes AI is installed and ready."
    static let downloadRequiredStatus = "Install Vibes AI first (~491 MB), then you can use KeyVox Vibes."
    static let downloadingStatus = "Downloading KeyVox Vibes AI."
    static let installingStatus = "Installing KeyVox Vibes AI."
    static let installFailedStatus = "Install failed."
    static let downloadAction = "Download"
    static let repairAction = "Repair"
    static let deleteAction = "Delete"
    static let triggerKeyInteractionsTitle = "Trigger Key Interactions"
    static let triggerKeyInteractionsSubtitle = "Tap to apply / undo Vibes. Double-tap to cycle Vibes."
    static let triggerKeyInteractionsAccessibilityLabel = "Vibes trigger key interactions"
    static let deleteConfirmationTitle = "Delete KeyVox Vibes AI?"
    static let deleteConfirmationMessage = "KeyVox Vibes AI will be removed from this Mac."
}
