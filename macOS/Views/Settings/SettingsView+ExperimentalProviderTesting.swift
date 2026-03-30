import SwiftUI
import KeyVoxCore

#if DEBUG
extension SettingsView {
    var experimentalProviderTestingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXPERIMENTAL PROVIDER TESTING")
                .font(.appFont(10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)

            ExperimentalProviderTestingCard(
                appSettings: appSettings,
                downloader: downloader
            )
        }
    }
}

private struct ExperimentalProviderTestingCard: View {
    @ObservedObject var appSettings: AppSettingsStore
    @ObservedObject var downloader: ModelDownloader

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(
                    icon: "waveform.badge.magnifyingglass",
                    title: "Active Provider",
                    subtitle: "Switch the dictation backend live for local testing."
                ) {
                    Picker("", selection: $appSettings.activeDictationProvider) {
                        ForEach(AppSettingsStore.ActiveDictationProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .labelsHidden()
                }

                Divider()
                    .overlay(Color.white.opacity(0.14))

                providerStatusRow(
                    title: "Whisper",
                    isActive: appSettings.activeDictationProvider == .whisper,
                    installState: downloader.state(for: .whisperBase),
                    allowsInstall: false
                )

                providerStatusRow(
                    title: "Parakeet",
                    isActive: appSettings.activeDictationProvider == .parakeet,
                    installState: downloader.state(for: .parakeetTdtV3),
                    allowsInstall: true
                )

                if !downloader.isModelDownloaded {
                    Text("Visible install controls still manage the default Whisper path.")
                        .font(.appFont(11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func providerStatusRow(
        title: String,
        isActive: Bool,
        installState: DictationModelInstallState,
        allowsInstall: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.appFont(13))
                    .foregroundColor(.primary)

                if isActive {
                    StatusBadge(title: "Active", color: .yellow)
                }

                let isReady = installState.isReady && !installState.isDownloading
                StatusBadge(title: isReady ? "Ready" : "Not Ready", color: isReady ? .green : .orange)

                Spacer()

                if allowsInstall {
                    if installState.isReady {
                        Button("Remove") {
                            downloader.deleteModel(withID: .parakeetTdtV3)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if installState.isDownloading {
                        StatusBadge(title: "Installing", color: .yellow)
                    } else {
                        Button("Install") {
                            downloader.downloadModel(withID: .parakeetTdtV3)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            if installState.isDownloading {
                ModelDownloadProgress(progress: installState.progress)
            }

            if let errorMessage = installState.errorMessage {
                Text(errorMessage)
                    .font(.appFont(10))
                    .foregroundColor(.red)
            }
        }
    }
}
#endif
