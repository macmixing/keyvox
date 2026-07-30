import SwiftUI
import KeyVoxCore

extension SettingsView {
    var dictationModelsSection: some View {
        DictationModelsCard(
            appSettings: appSettings,
            downloader: downloader,
            requestDeleteConfirmation: { dictationModelDeleteTarget = $0 }
        )
    }
}

private struct DictationModelsCard: View {
    @ObservedObject var appSettings: AppSettingsStore
    @ObservedObject var downloader: ModelDownloader
    let requestDeleteConfirmation: (DictationModelID) -> Void

    @State private var isModelSectionExpanded = false
    @State private var modelExpandedContentHeight: CGFloat = 0

    private static let sectionExpansionAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)
    // Ignore sub-point geometry jitter while still reacting to real content height changes.
    private static let modelHeightTolerance: CGFloat = 0.5

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                headerContent

                Divider()
                    .overlay(Color.white.opacity(0.22))

                HStack(alignment: .top, spacing: 12) {
                    Text(sectionDescriptionText)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        withAnimation(Self.sectionExpansionAnimation) {
                            isModelSectionExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isModelSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.yellow)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                modelExpandedContent
                    .frame(height: shouldShowExpandedModelContent ? modelExpandedContentHeight : 0, alignment: .top)
                    .clipped()
                    .allowsHitTesting(shouldShowExpandedModelContent)
                    .accessibilityHidden(!shouldShowExpandedModelContent)
                    .background(alignment: .top) {
                        if shouldShowExpandedModelContent || modelExpandedContentHeight == 0 {
                            modelExpandedContentMeasurement
                        }
                    }

                Divider()
                    .overlay(Color.white.opacity(0.22))

                DictationLanguageSection(
                    activeProvider: appSettings.activeDictationProvider,
                    selectedWhisperLanguage: $appSettings.whisperDictationLanguage
                )
            }
        }
        .onAppear {
            enforceSelectableActiveProvider()
        }
        .onChange(of: selectableProviders) { _ in
            enforceSelectableActiveProvider()
        }
    }

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)

                Image(systemName: "character.cursor.ibeam")
                    .font(.appFont(20))
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(DictationModelsCardCopy.cardTitle)
                    .font(.appFont(18))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            pickerControl
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var pickerControl: some View {
        if selectableProviders.isEmpty {
            Picker("", selection: unavailableProviderSelection) {
                Text(DictationModelsCardCopy.installModelPickerTitle)
                    .tag(AppSettingsStore.ActiveDictationProvider?.none)
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .labelsHidden()
            .disabled(true)
        } else {
            Picker("", selection: activeProviderSelection) {
                ForEach(selectableProviders) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .labelsHidden()
        }
    }

    private var modelExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(modelRows.enumerated()), id: \.element.id) { index, configuration in
                    DictationModelCardRow(
                        configuration: configuration,
                        isActive: appSettings.activeDictationProvider.modelID == configuration.modelID,
                        installState: downloader.state(for: configuration.modelID),
                        isBlockedByAnotherActiveInstall: isBlockedByAnotherActiveInstall(for: configuration.modelID),
                        downloader: downloader,
                        deleteAction: { requestDeleteConfirmation(configuration.modelID) }
                    )

                    if index < modelRows.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.22))
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
    }

    private var modelExpandedContentMeasurement: some View {
        modelExpandedContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateModelExpandedContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { newHeight in
                            updateModelExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    private var activeProviderSelection: Binding<AppSettingsStore.ActiveDictationProvider> {
        Binding(
            get: { appSettings.activeDictationProvider },
            set: { newValue in
                guard isProviderSelectable(newValue) else { return }
                appSettings.activeDictationProvider = newValue
            }
        )
    }

    private var unavailableProviderSelection: Binding<AppSettingsStore.ActiveDictationProvider?> {
        Binding(
            get: { nil },
            set: { _ in }
        )
    }

    private func isProviderSelectable(_ provider: AppSettingsStore.ActiveDictationProvider) -> Bool {
        downloader.isModelReady(for: provider.modelID)
    }

    private var selectableProviders: [AppSettingsStore.ActiveDictationProvider] {
        AppSettingsStore.ActiveDictationProvider.supportedCases().filter(isProviderSelectable)
    }

    private var sectionDescriptionText: String {
        if selectableProviders.isEmpty {
            return DictationModelsCardCopy.installDescription
        }

        return DictationModelsCardCopy.readyDescription
    }

    private var shouldShowExpandedModelContent: Bool {
        isModelSectionExpanded
    }

    private func enforceSelectableActiveProvider() {
        guard !isProviderSelectable(appSettings.activeDictationProvider) else { return }
        guard let fallback = AppSettingsStore.ActiveDictationProvider.supportedCases().first(where: isProviderSelectable) else { return }
        appSettings.activeDictationProvider = fallback
    }

    private func isBlockedByAnotherActiveInstall(for modelID: DictationModelID) -> Bool {
        modelRows.contains { configuration in
            configuration.modelID != modelID && downloader.state(for: configuration.modelID).isDownloading
        }
    }

    private func updateModelExpandedContentHeight(_ newHeight: CGFloat) {
        guard newHeight > 0 else { return }
        if abs(modelExpandedContentHeight - newHeight) > Self.modelHeightTolerance {
            modelExpandedContentHeight = newHeight
        }
    }

    private var modelRows: [DictationModelCardConfiguration] {
        var rows = [
            DictationModelCardConfiguration(
                modelID: .whisperBase,
                title: AppSettingsStore.ActiveDictationProvider.whisper.displayName,
                subtitle: DictationModelsCardCopy.whisperDescription
            )
        ]

        if AppSettingsStore.ActiveDictationProvider.parakeet.isSupported() {
            rows.append(
                DictationModelCardConfiguration(
                    modelID: .parakeetTdtV3,
                    title: AppSettingsStore.ActiveDictationProvider.parakeet.displayName,
                    subtitle: DictationModelsCardCopy.parakeetDescription
                )
            )
        }

        return rows
    }
}

private struct DictationModelCardConfiguration: Identifiable {
    let modelID: DictationModelID
    let title: String
    let subtitle: String

    var id: DictationModelID { modelID }
}

private struct DictationModelCardRow: View {
    let configuration: DictationModelCardConfiguration
    let isActive: Bool
    let installState: DictationModelInstallState
    let isBlockedByAnotherActiveInstall: Bool

    @ObservedObject var downloader: ModelDownloader
    let deleteAction: () -> Void

    private let actionPillWidth: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(configuration.title)
                        .font(.appFont(17))
                        .foregroundStyle(.white)

                    if isActive && installState.isReady {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                actionButton
            }

            if !installState.isReady && !installState.isDownloading {
                Text(configuration.subtitle)
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if installState.isDownloading {
                LabeledProgressBar(progress: installState.progress, statusText: statusText)
            } else {
                Text(statusText)
                    .font(.appFont(13, variant: .light))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = installState.errorMessage {
                Text(errorMessage)
                    .font(.appFont(12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if installState.isDownloading {
            EmptyView()
        } else if installState.isReady {
            AppActionButton(
                title: DictationModelsCardCopy.deleteAction,
                style: .destructive,
                minWidth: actionPillWidth,
                action: deleteAction
            )
        } else if installState.errorMessage != nil {
            AppActionButton(
                title: DictationModelsCardCopy.repairAction,
                style: .primary,
                minWidth: actionPillWidth,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: installModel
            )
        } else {
            AppActionButton(
                title: DictationModelsCardCopy.downloadAction,
                style: .primary,
                minWidth: actionPillWidth,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: installModel
            )
        }
    }

    private func installModel() {
        downloader.downloadModel(withID: configuration.modelID)
    }

    private var statusText: String {
        if installState.isDownloading {
            return DictationModelsCardCopy.installingStatus
        }

        if installState.isReady {
            return DictationModelsCardCopy.readyStatus
        }

        if installState.errorMessage != nil {
            return DictationModelsCardCopy.failedStatus
        }

        if let approximateSizeText {
            return "\(DictationModelsCardCopy.notInstalledStatus) (\(approximateSizeText))"
        }

        return DictationModelsCardCopy.notInstalledStatus
    }

    private var approximateSizeText: String? {
        switch configuration.modelID {
        case .whisperBase:
            return "~190 MB"
        case .parakeetTdtV3:
            return "~480 MB"
        }
    }
}

private enum DictationModelsCardCopy {
    static let cardTitle = "Dictation Model"
    static let installDescription = "Install a dictation model to let KeyVox transcribe speech on this Mac."
    static let readyDescription = "Choose which installed model KeyVox uses when transcribing speech on this Mac."
    static let installModelPickerTitle = "Install model"
    static let whisperDescription = "Accurate and lightweight."
    static let parakeetDescription = "Lightning fast, heavier footprint."
    static let notInstalledStatus = "Not installed"
    static let installingStatus = "Installing"
    static let failedStatus = "Install failed"
    static let readyStatus = "Ready"
    static let downloadAction = "Download"
    static let repairAction = "Repair"
    static let deleteAction = "Delete"
}
