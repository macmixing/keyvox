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
                        isSelectionEnabled: matrix.showsVibeSelector
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
            StatusBadge(title: progressBadgeTitle, backgroundColor: .yellow)
                .frame(width: 84)
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

    private var progressBadgeTitle: String {
        switch matrix.mainCardContent {
        case .installing:
            return SettingsVibesCardCopy.installingBadge
        case .downloading:
            return SettingsVibesCardCopy.downloadingBadge
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
    static let cardSubtitle = "On-device, reversible writing styles for Mac & iOS."
    static let pickerAccessibilityLabel = "KeyVox Vibes"
    static let downloadRequiredStatus = "Install Vibes AI first (~491 MB), then you can use KeyVox Vibes."
    static let downloadingStatus = "Downloading KeyVox Vibes AI."
    static let installingStatus = "Installing KeyVox Vibes AI."
    static let installFailedStatus = "Install failed."
    static let readyStatus = "KeyVox Vibes AI is installed and ready."
    static let downloadingBadge = "Downloading"
    static let installingBadge = "Installing"
    static let downloadAction = "Download"
    static let repairAction = "Repair"
    static let triggerTip = "Tap the trigger key to apply / undo the current Vibe. Double-tap to cycle Vibes."
    static let helpAccessibilityLabel = "Learn about KeyVox Vibes"
}
