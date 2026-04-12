import SwiftUI

extension SettingsTabView {
    @ViewBuilder
    var activeModelSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text Model")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.activeDictationProvider.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if selectableProviders.isEmpty {
                        Text("Install model")
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
                            Text("Change")
                                .font(.appFont(16))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.top, 2)
                    }
                }

                Divider()
                    .background(.white.opacity(0.22))

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
            }
        }
    }

    @ViewBuilder
    private var modelExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(DictationModelID.allCases.enumerated()), id: \.element) { index, modelID in
                    modelRow(for: modelID, provider: modelID.provider)

                    if index < DictationModelID.allCases.count - 1 {
                        Divider()
                            .background(.white.opacity(0.22))
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

            HStack(alignment: .center, spacing: 12) {
                Text(modelStatusText(for: modelID, state: state))
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
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
                title: "Install",
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: { modelManager.downloadModel(withID: modelID) }
            )
        case .ready:
            AppActionButton(
                title: "Delete",
                style: .destructive,
                size: .compact,
                fontSize: 15,
                action: { pendingDeletionConfirmation = .dictationModel(modelID) }
            )
        case .failed:
            AppActionButton(
                title: "Repair",
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
        case .ready, .failed, .notInstalled:
            break
        }

        guard case .notInstalled = state,
              let approximateSizeText = notInstalledApproximateSizeText(for: modelID) else {
            return state.statusText
        }

        return "\(state.statusText) (\(approximateSizeText))"
    }

    func modelProgressPercentageText(for state: ModelInstallState) -> String? {
        let progress: Double
        switch state {
        case .downloading(let currentProgress, _), .installing(let currentProgress, _):
            progress = currentProgress
        case .notInstalled, .ready, .failed:
            return nil
        }

        return "\(Int((progress * 100).rounded()))%"
    }

    func notInstalledApproximateSizeText(for modelID: DictationModelID) -> String? {
        switch modelID {
        case .whisperBase:
            return "~190 MB"
        case .parakeetTdtV3:
            return "~480 MB"
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

    var textModelDescriptionText: String {
        if selectableProviders.isEmpty {
            return "Install a text model to let KeyVox transcribe speech on this device."
        }
        return "Choose which installed model KeyVox uses when transcribing speech on this device."
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
