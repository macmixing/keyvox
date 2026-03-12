import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var modelManager: iOSModelManager
    @EnvironmentObject private var settingsStore: iOSAppSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                audioSection
                modelSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            modelManager.refreshStatus()
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio")
                .font(.headline)

            Toggle("Prefer Built-In Microphone", isOn: $settingsStore.preferBuiltInMicrophone)

            Text(settingsStore.preferBuiltInMicrophone
                 ? "KeyVox will prefer the built-in microphone whenever one is available."
                 : "KeyVox will use the currently connected input device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model")
                .font(.headline)

            Text(modelManager.installState.statusText)
                .font(.footnote.monospaced())

            if let error = modelManager.errorMessage {
                Text(error)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                switch modelManager.installState {
                case .notInstalled:
                    Button("Download Model") {
                        modelManager.downloadModel()
                    }
                case .downloading, .installing:
                    if let actionText = modelManager.installState.actionText {
                        Text(actionText)
                            .font(.footnote.monospaced())
                    }
                case .ready:
                    Button("Delete Model") {
                        modelManager.deleteModel()
                    }
                case .failed:
                    Button("Repair Model") {
                        modelManager.repairModelIfNeeded()
                    }
                    Button("Delete Model") {
                        modelManager.deleteModel()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(iOSAppServiceRegistry.shared.modelManager)
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
}
