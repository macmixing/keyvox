import SwiftUI
import KeyVoxStyleRewrite

struct SettingsVibesCard: View {
    @Binding var selectedVibe: StyleRewriteStyle
    let installState: MacLocalRewriteModelInstallState
    let downloadAction: () -> Void
    let repairAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsRow(
                        assetIcon: "vibes-logo",
                        title: MacVibesSettingsCopy.cardTitle,
                        subtitle: MacVibesSettingsCopy.cardSubtitle
                    ) {
                        cardControl
                    }

                    Divider()
                        .background(Color.white.opacity(0.22))

                    statusContent

                    if matrix.showsVibeSelector {
                        Divider()
                            .background(Color.white.opacity(0.22))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(StyleRewriteStyle.allCases) { style in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(style.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text(style.exampleText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(MacAppTheme.accent)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
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
            Text(matrix.statusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
