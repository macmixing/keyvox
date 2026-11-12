import Foundation
import KeyVoxCore
import SwiftUI

extension DictationSettingsView {
    @ViewBuilder
    var activeModelSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dictation Model", comment: "Title of the dictation settings card for choosing and installing speech recognition models.")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.activeDictationProvider.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if selectableProviders.isEmpty {
                        Text("Install model", comment: "Shown in place of the Change button on the Dictation Model card when no model is installed yet.")
                            .font(.appFont(14))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Menu {
                            Picker("", selection: activeProviderSelection) {
                                ForEach(selectableProviders) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Text("Change", comment: "Menu button on the Dictation Model card that opens the list of installed models.")
                                .font(.appFont(16))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.top, 2)
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(textModelDescriptionText)
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if showsCombinedTextModelCellularWarning {
                            InlineWarningRow(text: InlineWarningRow.Copy.cellularModelDownloadRecommended)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        appHaptics.light()
                        withAnimation(SettingsTabView.sectionExpansionAnimation) {
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
                    .overlay(.white.opacity(0.22))

                dictationLanguageSection
            }
        }
        .id(DictationSettingsScrollTarget.dictationModel)
    }

    @ViewBuilder
    private var dictationLanguageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.4))
                        .frame(width: 32, height: 32)

                    Image(systemName: "textformat.characters.dottedunderline")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Language", comment: "Title of the dictation language setting.")
                        .font(.appFont(18))
                        .foregroundStyle(.white)

                    Text(activeDictationLanguageDisplayName)
                        .font(.appFont(17))
                        .foregroundStyle(.yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if settingsStore.activeDictationProvider == .whisper {
                    Button {
                        appHaptics.light()
                        isLanguagePickerPresented = true
                    } label: {
                        Text("Change", comment: "Button on the dictation Language setting that opens the language list.")
                            .font(.appFont(16))
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Text(dictationLanguageDescriptionText)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private var modelExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(DictationModelID.allCases.enumerated()), id: \.element) { index, modelID in
                    modelRow(for: modelID, provider: modelID.provider)

                    if index < DictationModelID.allCases.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.22))
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
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
                        .onChange(of: geometry.size.height) { _, newHeight in
                            updateModelExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    @ViewBuilder
    func modelRow(
        for modelID: DictationModelID,
        provider: AppSettingsStore.ActiveDictationProvider
    ) -> some View {
        let state = modelManager.state(for: modelID)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(provider.displayName)
                        .font(.appFont(17))
                        .foregroundStyle(.white)

                    if settingsStore.activeDictationProvider == provider && modelManager.isModelReady(for: modelID) {
                        Circle()
                            .fill(.yellow)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                actionButton(for: modelID, state: state)
            }

            if case .notInstalled = state,
               let descriptionText = modelDescriptionText(for: modelID) {
                Text(descriptionText)
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(modelStatusText(for: modelID, state: state))
                    .font(.appFont(13, variant: .light))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let percentageText = modelProgressPercentageText(for: state) {
                    Text(percentageText)
                        .font(.appFont(14, variant: .medium))
                        .foregroundStyle(.yellow)
                }
            }

            if case .failed(let message) = state {
                    Text(message)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
            }

            if InlineWarningRules.showsSettingsIndividualTextModelWarning(
                isOnCellular: downloadNetworkMonitor.isOnCellular,
                showsCombinedWarning: showsCombinedTextModelCellularWarning,
                modelState: state
            ) {
                InlineWarningRow(text: InlineWarningRow.Copy.cellularDownloadRecommended)
            }

            switch state {
            case .downloading(let progress, _), .installing(let progress, _):
                ModelDownloadProgress(progress: progress, showLabel: false)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    func actionButton(for modelID: DictationModelID, state: ModelInstallState) -> some View {
        let isBlockedByAnotherActiveInstall =
            modelManager.activeInstallModelID().map { $0 != modelID } ?? false

        switch state {
        case .notInstalled:
            AppActionButton(
                title: String(localized: "Download", comment: "Button on a dictation model row that downloads the model."),
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: { pendingDownloadConfirmation = .dictationModel(modelID) }
            )
        case .ready:
            if modelManager.requiresArtifactUpdate(for: modelID) {
                AppActionButton(
                    title: String(localized: "Update", comment: "Button on a dictation model row that downloads a newer version of the model."),
                    style: .primary,
                    size: .compact,
                    fontSize: 15,
                    isEnabled: !isBlockedByAnotherActiveInstall,
                    action: { modelManager.repairModelIfNeeded(for: modelID) }
                )
            } else {
                AppActionButton(
                    title: String(localized: "Delete", comment: "Button on a dictation model row that deletes the downloaded model."),
                    style: .destructive,
                    size: .compact,
                    fontSize: 15,
                    action: { pendingDeletionConfirmation = .dictationModel(modelID) }
                )
            }
        case .failed:
            AppActionButton(
                title: String(localized: "Repair", comment: "Button on a dictation model row that retries a failed install."),
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: { modelManager.repairModelIfNeeded(for: modelID) }
            )
        case .downloading, .installing:
            EmptyView()
        }
    }

    func modelStatusText(for modelID: DictationModelID, state: ModelInstallState) -> String {
        switch state {
        case .downloading(_, let phase), .installing(_, let phase):
            return phase.statusText
        case .ready:
            if modelManager.requiresArtifactUpdate(for: modelID) {
                return String(localized: "Update available", comment: "Status on a dictation model row when a newer version of the installed model can be downloaded.")
            }
        case .failed, .notInstalled:
            break
        }

        guard case .notInstalled = state,
              let approximateSizeText = notInstalledApproximateSizeText(for: modelID) else {
            return state.statusText
        }

        return String(localized: "\(state.statusText) (\(approximateSizeText))", comment: "Status on a dictation model row that is not installed. The first placeholder is the install status and the second is the approximate download size.")
    }

    func modelProgressPercentageText(for state: ModelInstallState) -> String? {
        let progress: Double
        switch state {
        case .downloading(let currentProgress, _), .installing(let currentProgress, _):
            progress = currentProgress
        case .notInstalled, .ready, .failed:
            return nil
        }

        return progress.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
    }

    func notInstalledApproximateSizeText(for modelID: DictationModelID) -> String? {
        switch modelID {
        case .whisperBase:
            return ApproximateDownloadSize.whisperBase
        case .parakeetTdtV3:
            return ApproximateDownloadSize.parakeet
        }
    }

    func modelDescriptionText(for modelID: DictationModelID) -> String? {
        switch modelID {
        case .whisperBase:
            return String(localized: "Accurate and lightweight.", comment: "Short description of the Whisper Base dictation model on its row in dictation settings.")
        case .parakeetTdtV3:
            return String(localized: "Lightning fast, heavier footprint.", comment: "Short description of the Parakeet dictation model on its row in dictation settings: very fast, but uses more storage and memory.")
        }
    }

    var selectableProviders: [AppSettingsStore.ActiveDictationProvider] {
        AppSettingsStore.ActiveDictationProvider.allCases.filter {
            modelManager.isModelReady(for: $0.modelID)
        }
    }

    var activeProviderSelection: Binding<AppSettingsStore.ActiveDictationProvider> {
        Binding(
            get: { settingsStore.activeDictationProvider },
            set: { newValue in
                guard selectableProviders.contains(newValue) else { return }
                settingsStore.activeDictationProvider = newValue
            }
        )
    }

    var activeDictationLanguageDisplayName: String {
        let language: DictationLanguage = switch settingsStore.activeDictationProvider {
        case .whisper:
            settingsStore.whisperDictationLanguage
        case .parakeet:
            .automatic
        }

        return DictationLanguageDisplayNameFormatter.displayName(for: language)
    }

    var dictationLanguageDescriptionText: String {
        switch settingsStore.activeDictationProvider {
        case .whisper:
            return String(localized: "Choose the language KeyVox uses for dictation.", comment: "Description under the dictation Language setting when Whisper is the active model. KeyVox is a brand name and stays in English.")
        case .parakeet:
            return String(localized: "Parakeet automatically detects the language used for dictation. Visit the FAQ in the Need Help? card to see its supported languages.", comment: "Description under the dictation Language setting when Parakeet is the active model. Parakeet is a brand name and stays in English. Need Help? is the title of a card in Settings; translate it the same way as that card's title.")
        }
    }

    var textModelDescriptionText: String {
        if selectableProviders.isEmpty {
            return String(localized: "Install a dictation model to let KeyVox transcribe speech on this device.", comment: "Description on the Dictation Model card when no model is installed. KeyVox is a brand name and stays in English.")
        }
        return String(localized: "Choose which installed model KeyVox uses when transcribing speech on this device.", comment: "Description on the Dictation Model card when at least one model is installed. KeyVox is a brand name and stays in English.")
    }

    var shouldShowExpandedModelContent: Bool {
        isModelSectionExpanded
    }

    var showsCombinedTextModelCellularWarning: Bool {
        InlineWarningRules.showsSettingsCombinedTextModelWarning(
            isOnCellular: downloadNetworkMonitor.isOnCellular,
            modelStates: DictationModelID.allCases.map { modelManager.state(for: $0) }
        )
    }

    func updateModelExpandedContentHeight(_ newHeight: CGFloat) {
        guard newHeight > 0 else { return }
        if abs(modelExpandedContentHeight - newHeight) > 0.5 {
            modelExpandedContentHeight = newHeight
        }
    }
}
