import SwiftUI
import KeyVoxCore

extension SettingsView {
    var dictationModelsSection: some View {
        DictationModelsCard(
            appSettings: appSettings,
            downloader: downloader
        )
    }
}

private struct DictationModelsCard: View {
    @ObservedObject var appSettings: AppSettingsStore
    @ObservedObject var downloader: ModelDownloader

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(
                    icon: "cpu",
                    title: "Active Model",
                    subtitle: "Choose the dictation backend and manage installed models."
                ) {
                    if selectableProviders.isEmpty {
                        Picker("", selection: unavailableProviderSelection) {
                            Text("Install model")
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

                Divider()
                    .overlay(Color.white.opacity(0.14))

                ForEach(modelRows) { configuration in
                    DictationModelCardRow(
                        configuration: configuration,
                        isActive: appSettings.activeDictationProvider.modelID == configuration.modelID,
                        installState: downloader.state(for: configuration.modelID),
                        downloader: downloader
                    )

                    if configuration.modelID != modelRows.last?.modelID {
                        Divider()
                            .overlay(Color.white.opacity(0.14))
                    }
                }
            }
        }
        .onAppear {
            enforceSelectableActiveProvider()
        }
        .onChange(of: selectableProviders) { _ in
            enforceSelectableActiveProvider()
        }
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

    private func enforceSelectableActiveProvider() {
        guard !isProviderSelectable(appSettings.activeDictationProvider) else { return }
        guard let fallback = AppSettingsStore.ActiveDictationProvider.supportedCases().first(where: isProviderSelectable) else { return }
        appSettings.activeDictationProvider = fallback
    }

    private var modelRows: [DictationModelCardConfiguration] {
        var rows = [
            DictationModelCardConfiguration(
                modelID: .whisperBase,
                title: "OpenAI Whisper Base",
                subtitle: "Locally powered multi-lingual model."
            )
        ]

        if AppSettingsStore.ActiveDictationProvider.parakeet.isSupported() {
            rows.append(
                DictationModelCardConfiguration(
                    modelID: .parakeetTdtV3,
                    title: "Parakeet TDT v3",
                    subtitle: "Locally powered transducer model."
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

    @ObservedObject var downloader: ModelDownloader
    @State private var isReadyHovered = false

    private let actionPillWidth: CGFloat = 84

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(configuration.title)
                            .font(.appFont(13))
                            .foregroundColor(.primary)

                        if isActive {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 7, height: 7)
                        }
                    }

                    Text(configuration.subtitle)
                        .font(.appFont(12, variant: .light))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    ZStack(alignment: .trailing) {
                        if installState.isReady && !installState.isDownloading {
                            Button(action: removeModel) {
                                removeButtonLabel
                                    .frame(width: actionPillWidth)
                            }
                            .buttonStyle(.plain)
                            .opacity(isReadyHovered ? 1.0 : 0.0)
                            .allowsHitTesting(isReadyHovered)

                            readyBadgeLabel
                                .frame(width: actionPillWidth)
                                .opacity(isReadyHovered ? 0.0 : 1.0)
                        } else if installState.isDownloading {
                            StatusBadge(title: "Installing", color: .yellow)
                        } else {
                            AppActionButton(
                                title: "Install",
                                style: .primary,
                                minWidth: actionPillWidth
                            ) {
                                installModel()
                            }
                        }
                    }
                }
                .onHover { isReadyHovered = $0 }
                .animation(.none, value: isReadyHovered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if installState.isDownloading {
                ModelDownloadProgress(progress: installState.progress)
                    .padding(.leading, 60)
            }

            if let errorMessage = installState.errorMessage {
                Text(errorMessage)
                    .font(.appFont(10))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func installModel() {
        downloader.downloadModel(withID: configuration.modelID)
    }

    private func removeModel() {
        downloader.deleteModel(withID: configuration.modelID)
    }

    private var removeButtonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "xmark.circle.fill")
            Text("REMOVE")
        }
        .font(.appFont(9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var readyBadgeLabel: some View {
        Text("READY")
            .font(.appFont(9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
    }
}
