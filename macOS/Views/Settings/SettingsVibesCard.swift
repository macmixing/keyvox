import SwiftUI
import KeyVoxStyleRewrite

struct SettingsVibesCard: View {
    @Binding var selectedVibe: StyleRewriteStyle
    let installState: MacLocalRewriteModelInstallState
    let downloadAction: () -> Void
    let repairAction: () -> Void

    @State private var isVibeExamplesExpanded = false
    @State private var vibeExamplesExpandedContentHeight: CGFloat = 0

    private static let sectionExpansionAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84)

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

                    HStack(alignment: .top, spacing: 12) {
                        Text(matrix.displayedSelectedVibe.description)
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            withAnimation(Self.sectionExpansionAnimation) {
                                isVibeExamplesExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isVibeExamplesExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(.yellow)
                                .frame(width: 56, height: 56)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isVibeExamplesExpanded
                            ? MacVibesSettingsCopy.hideExamplesAccessibilityLabel
                            : MacVibesSettingsCopy.showExamplesAccessibilityLabel
                        )
                    }

                    vibeExamplesExpandedContent
                        .frame(height: isVibeExamplesExpanded ? vibeExamplesExpandedContentHeight : 0, alignment: .top)
                        .clipped()
                        .allowsHitTesting(isVibeExamplesExpanded)
                        .accessibilityHidden(!isVibeExamplesExpanded)
                        .background(alignment: .top) {
                            if isVibeExamplesExpanded || vibeExamplesExpandedContentHeight == 0 {
                                vibeExamplesExpandedContentMeasurement
                            }
                        }
                }
            }

            HStack {
                Spacer()
                TipItem(
                    icon: "keyboard",
                    text: MacVibesSettingsCopy.triggerTip
                )
                Spacer()
            }
        }
    }

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MacAppTheme.accent.opacity(0.4))
                    .frame(width: 32, height: 32)

                Image("vibes-logo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(MacAppTheme.accent)
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(MacVibesSettingsCopy.cardTitle)
                    .font(.appFont(18))
                    .foregroundStyle(.white)
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
                title: MacVibesSettingsCopy.downloadAction,
                style: .primary,
                minWidth: 84,
                action: downloadAction
            )
        case .repair:
            AppActionButton(
                title: MacVibesSettingsCopy.repairAction,
                style: .primary,
                minWidth: 84,
                action: repairAction
            )
        case .progress:
            StatusBadge(title: progressBadgeTitle, color: .yellow)
                .frame(width: 84)
        case .change:
            Picker("", selection: $selectedVibe) {
                ForEach(StyleRewriteStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel(MacVibesSettingsCopy.pickerAccessibilityLabel)
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusText)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let progress = matrix.progress {
                ModelDownloadProgress(progress: progress)
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
            return MacVibesSettingsCopy.installingBadge
        case .downloading:
            return MacVibesSettingsCopy.downloadingBadge
        case .downloadRequired, .installFailed, .selectedVibe:
            return ""
        }
    }

    private var statusText: String {
        switch matrix.mainCardContent {
        case .downloadRequired:
            return MacVibesSettingsCopy.downloadRequiredStatus
        case .downloading:
            return MacVibesSettingsCopy.downloadingStatus
        case .installing:
            return MacVibesSettingsCopy.installingStatus
        case .installFailed:
            return MacVibesSettingsCopy.installFailedStatus
        case .selectedVibe:
            return MacVibesSettingsCopy.readyStatus
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

    private var vibeExamplesExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(vibeExamples.enumerated()), id: \.element.style) { index, example in
                    vibeExampleRow(example)

                    if index < vibeExamples.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.22))
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
                    }
                }
            }
        }
    }

    private var vibeExamplesExpandedContentMeasurement: some View {
        vibeExamplesExpandedContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateVibeExamplesExpandedContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { newHeight in
                            updateVibeExamplesExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    private func vibeExampleRow(_ example: VibeExample) -> some View {
        Button {
            guard matrix.showsVibeSelector else { return }
            selectedVibe = example.style
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(example.style.displayName)
                        .font(.appFont(17))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(example.text)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: example.style == matrix.displayedSelectedVibe ? "checkmark.circle.fill" : "checkmark.circle.dotted")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(example.style == matrix.displayedSelectedVibe ? .green : .white)
            }
            .padding(.leading, 10)
            .padding(.trailing, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }

    private func updateVibeExamplesExpandedContentHeight(_ newHeight: CGFloat) {
        guard abs(vibeExamplesExpandedContentHeight - newHeight) > 0.5 else { return }
        vibeExamplesExpandedContentHeight = newHeight
    }

    private var vibeExamples: [VibeExample] {
        StyleRewriteStyle.allCases.map { style in
            VibeExample(style: style, text: style.exampleText)
        }
    }

    private struct VibeExample: Hashable {
        let style: StyleRewriteStyle
        let text: String
    }
}

enum MacVibesSettingsCopy {
    static let cardTitle = "KeyVox Vibes"
    static let aiCardTitle = "KeyVox Vibes AI"
    static let aiReadyStatus = "KeyVox Vibes AI is installed and ready."
    static let aiDownloadRequiredStatus = "Install Vibes AI first (~491 MB), then you can use KeyVox Vibes."
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
    static let deleteAction = "Delete"
    static let showExamplesAccessibilityLabel = "Show vibe examples"
    static let hideExamplesAccessibilityLabel = "Hide vibe examples"
    static let triggerTip = "Tap the trigger key to apply / undo the current Vibe. Double-tap to cycle Vibes."
    static let deleteConfirmationTitle = "Delete KeyVox Vibes AI?"
    static let deleteConfirmationMessage = "KeyVox Vibes AI will be removed from this Mac."
}

struct SettingsVibesAIInstallCard: View {
    let installState: MacLocalRewriteModelInstallState
    let downloadAction: () -> Void
    let repairAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        SettingsCard {
            VStack(spacing: 16) {
                SettingsRow(
                    assetIcon: "vibes-logo",
                    title: MacVibesSettingsCopy.aiCardTitle,
                    subtitle: subtitleText
                ) {
                    actionControl
                }

                if shouldShowInstallContent {
                    Divider()
                        .background(Color.white.opacity(0.22))

                    installContent
                }
            }
        }
    }

    @ViewBuilder
    private var actionControl: some View {
        switch installState {
        case .notInstalled:
            AppActionButton(
                title: MacVibesSettingsCopy.downloadAction,
                style: .primary,
                minWidth: 84,
                action: downloadAction
            )
        case .ready:
            AppActionButton(
                title: MacVibesSettingsCopy.deleteAction,
                style: .destructive,
                minWidth: 84,
                action: deleteAction
            )
        case .failed:
            AppActionButton(
                title: MacVibesSettingsCopy.repairAction,
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
            HStack(alignment: .center, spacing: 12) {
                Text(statusText)
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let percentageText {
                    Text(percentageText)
                        .font(.appFont(12))
                        .foregroundStyle(.yellow)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.appFont(10))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let progress {
                ModelDownloadProgress(progress: progress)
            }
        }
    }

    private var subtitleText: String {
        switch installState {
        case .ready:
            return MacVibesSettingsCopy.aiReadyStatus
        case .notInstalled, .downloading, .installing, .failed:
            return MacVibesSettingsCopy.aiDownloadRequiredStatus
        }
    }

    private var statusText: String {
        switch installState {
        case .downloading:
            return MacVibesSettingsCopy.downloadingStatus
        case .installing:
            return MacVibesSettingsCopy.installingStatus
        case .failed:
            return MacVibesSettingsCopy.installFailedStatus
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

    private var percentageText: String? {
        guard let progress else { return nil }
        return "\(Int((progress * 100).rounded()))%"
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
