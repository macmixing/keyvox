import Foundation
import SwiftUI
import KeyVoxStyleRewrite

struct SettingsVibesCard: View {
    @Binding var selectedVibe: StyleRewriteStyle
    let dictationModel: StyleRewriteDictationModel
    let installState: MacLocalRewriteModelInstallState
    let downloadAction: () -> Void
    let repairAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    headerContent

                    if shouldShowStatusContent {
                        statusContent
                    }

                    Divider()
                        .overlay(.white.opacity(0.22))

                    SettingsVibesExamplesSection(
                        selectedVibe: $selectedVibe,
                        displayedSelectedVibe: matrix.displayedSelectedVibe,
                        dictationModel: dictationModel,
                        isSelectionEnabled: matrix.showsVibeSelector,
                        isDownloadRequired: matrix.mainCardContent == .downloadRequired
                    )
                }
            }

            HStack {
                Spacer()
                TipItem(
                    icon: "keyboard",
                    text: SettingsVibesCardCopy.triggerTip
                )
                Spacer()
            }
        }
    }

    private var headerContent: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)

                Image("vibes-logo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.yellow)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Text(SettingsVibesCardCopy.cardTitle)
                        .font(.appFont(18))
                        .foregroundStyle(.white)

                    Button(action: {
                        WindowManager.shared.showVibesIntroWindow(initialScene: .b)
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.yellow)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(SettingsVibesCardCopy.helpAccessibilityLabel)
                }

                Text(SettingsVibesCardCopy.cardSubtitle)
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            cardControl
                .padding(.top, 2)
        }
    }

    private var matrix: MacVibesAccessMatrix {
        MacVibesAccessMatrix.resolve(
            modelState: MacVibesAccessMatrix.modelState(from: installState),
            selectedVibe: selectedVibe
        )
    }

    @ViewBuilder
    private var cardControl: some View {
        switch matrix.cardControl {
        case .download:
            AppActionButton(
                title: SettingsVibesCardCopy.downloadAction,
                style: .primary,
                minWidth: 84,
                action: downloadAction
            )
        case .repair:
            AppActionButton(
                title: SettingsVibesCardCopy.repairAction,
                style: .primary,
                minWidth: 84,
                action: repairAction
            )
        case .progress:
            AppActionButton(
                title: progressActionTitle,
                style: .primary,
                minWidth: 84,
                isEnabled: false,
                action: {}
            )
        case .change:
            Picker("", selection: $selectedVibe) {
                ForEach(StyleRewriteStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel(SettingsVibesCardCopy.pickerAccessibilityLabel)
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let progress = matrix.progress {
                LabeledProgressBar(progress: progress, statusText: statusText)
            } else {
                Text(statusText)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = matrix.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var progressActionTitle: String {
        switch matrix.mainCardContent {
        case .installing:
            return SettingsVibesCardCopy.installingAction
        case .downloading:
            return SettingsVibesCardCopy.downloadingAction
        case .downloadRequired, .installFailed, .selectedVibe:
            return ""
        }
    }

    private var statusText: String {
        switch matrix.mainCardContent {
        case .downloadRequired:
            return SettingsVibesCardCopy.downloadRequiredStatus
        case .downloading:
            return SettingsVibesCardCopy.downloadingStatus
        case .installing:
            return SettingsVibesCardCopy.installingStatus
        case .installFailed:
            return SettingsVibesCardCopy.installFailedStatus
        case .selectedVibe:
            return SettingsVibesCardCopy.readyStatus
        }
    }

    private var shouldShowStatusContent: Bool {
        if matrix.progress != nil || matrix.errorMessage != nil {
            return true
        }

        switch matrix.mainCardContent {
        case .selectedVibe:
            return false
        case .downloadRequired, .downloading, .installing, .installFailed:
            return true
        }
    }
}

enum SettingsVibesCardCopy {
    static let cardTitle = "KeyVox Vibes"
    static let cardSubtitle = String(localized: "On-device, reversible writing styles for Mac & iOS.", comment: "Subtitle of the KeyVox Vibes card in Settings. Mac and iOS are Apple product names; use Apple's official names in this language.")
    static let pickerAccessibilityLabel = "KeyVox Vibes"
    static let downloadRequiredStatus = String(localized: "Install Vibes AI first (\(ApproximateDownloadSize.vibesAI)), then you can use KeyVox Vibes.", comment: "Subtitle of the KeyVox Vibes AI card in Settings before the Vibes model is installed. The placeholder in parentheses is the approximate download size. Vibes AI and KeyVox Vibes are brand names and stay in English.")
    static let downloadingStatus = String(localized: "Downloading KeyVox Vibes AI.", comment: "Progress label on the KeyVox Vibes AI card in Settings while the Vibes model downloads. KeyVox Vibes AI is a brand name and stays in English.")
    static let installingStatus = String(localized: "Installing KeyVox Vibes AI.", comment: "Progress label on the KeyVox Vibes AI card in Settings while the Vibes model installs. KeyVox Vibes AI is a brand name and stays in English.")
    static let installFailedStatus = String(localized: "Install failed.", comment: "Progress label on the KeyVox Vibes AI card in Settings when the Vibes model install fails.")
    static let readyStatus = String(localized: "KeyVox Vibes AI is installed and ready.", comment: "Subtitle of the KeyVox Vibes AI card in Settings when the Vibes model is installed. KeyVox Vibes AI is a brand name and stays in English.")
    static let downloadingAction = String(localized: "Downloading", comment: "Disabled button on the KeyVox Vibes card in Settings while the Vibes model downloads.")
    static let installingAction = String(localized: "Installing", comment: "Disabled button on the KeyVox Vibes card in Settings while the Vibes model installs.")
    static let downloadAction = String(localized: "Download", comment: "Button on the KeyVox Vibes card in Settings that downloads the Vibes model.")
    static let repairAction = String(localized: "Repair", comment: "Button on the KeyVox Vibes card in Settings that downloads the Vibes model again after a failed install.")
    static let triggerTip = String(localized: "Tap the trigger key to apply / undo the current Vibe. Double-tap to cycle Vibes.", comment: "Tip under the KeyVox Vibes card in Settings. Vibe and Vibes are brand names and stay in English.")
    static let helpAccessibilityLabel = String(localized: "Learn about KeyVox Vibes", comment: "VoiceOver label for the help button on the KeyVox Vibes card in Settings. KeyVox Vibes is a brand name and stays in English.")
}
