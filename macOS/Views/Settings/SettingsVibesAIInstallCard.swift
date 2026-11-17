import Foundation
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
                .disabled(isTriggerKeyInteractionsAvailable == false)
                .accessibilityLabel(SettingsVibesAIInstallCardCopy.triggerKeyInteractionsAccessibilityLabel)
        }
    }

    private var isTriggerKeyInteractionsAvailable: Bool {
        installState == .ready
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
    static let readyStatus = String(localized: "KeyVox Vibes AI is installed and ready.", comment: "Subtitle of the KeyVox Vibes AI card in Settings when the Vibes model is installed. KeyVox Vibes AI is a brand name and stays in English.")
    static let downloadRequiredStatus = String(localized: "Install Vibes AI first (\(ApproximateDownloadSize.vibesAI)), then you can use KeyVox Vibes.", comment: "Subtitle of the KeyVox Vibes AI card in Settings before the Vibes model is installed. The placeholder in parentheses is the approximate download size. Vibes AI and KeyVox Vibes are brand names and stay in English.")
    static let downloadingStatus = String(localized: "Downloading KeyVox Vibes AI.", comment: "Progress label on the KeyVox Vibes AI card in Settings while the Vibes model downloads. KeyVox Vibes AI is a brand name and stays in English.")
    static let installingStatus = String(localized: "Installing KeyVox Vibes AI.", comment: "Progress label on the KeyVox Vibes AI card in Settings while the Vibes model installs. KeyVox Vibes AI is a brand name and stays in English.")
    static let installFailedStatus = String(localized: "Install failed.", comment: "Progress label on the KeyVox Vibes AI card in Settings when the Vibes model install fails.")
    static let downloadAction = String(localized: "Download", comment: "Button on the KeyVox Vibes AI card in Settings that downloads the Vibes model.")
    static let repairAction = String(localized: "Repair", comment: "Button on the KeyVox Vibes AI card in Settings that downloads the Vibes model again after a failed install.")
    static let deleteAction = String(localized: "Delete", comment: "Button on the KeyVox Vibes AI card in Settings that deletes the Vibes model.")
    static let triggerKeyInteractionsTitle = String(localized: "Trigger Key Interactions", comment: "Toggle title on the KeyVox Vibes AI card in Settings for using the dictation trigger key to control Vibes.")
    static let triggerKeyInteractionsSubtitle = String(localized: "Tap to apply / undo Vibes. Double-tap to cycle Vibes.", comment: "Description under the Trigger Key Interactions toggle in Settings. Vibes is a brand name and stays in English.")
    static let triggerKeyInteractionsAccessibilityLabel = String(localized: "Vibes trigger key interactions", comment: "VoiceOver label for the Trigger Key Interactions toggle in Settings. Vibes is a brand name and stays in English.")
    static let deleteConfirmationTitle = String(localized: "Delete KeyVox Vibes AI?", comment: "Title of the confirmation prompt for deleting the Vibes model. KeyVox Vibes AI is a brand name and stays in English.")
    static let deleteConfirmationMessage = String(localized: "KeyVox Vibes AI will be removed from this Mac.", comment: "Message of the confirmation prompt for deleting the Vibes model. KeyVox Vibes AI is a brand name and stays in English.")
}
