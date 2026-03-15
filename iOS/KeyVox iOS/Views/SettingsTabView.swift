import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var modelManager: iOSModelManager
    @EnvironmentObject private var settingsStore: iOSAppSettingsStore

    var body: some View {
        iOSAppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                sessionSection
                keyboardSection
                audioSection
                modelSection
            }
        }
        .task {
            modelManager.refreshStatus()
        }
    }

    @ViewBuilder
    private var sessionSection: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session")
                    .font(.appFont(17))
                    .foregroundStyle(.white)

                Picker("Disable Session After", selection: $settingsStore.sessionDisableTiming) {
                    ForEach(iOSSessionDisableTiming.allCases) { timing in
                        Text(timing.displayName).tag(timing)
                    }
                }
                .pickerStyle(.menu)
                .font(.appFont(14, variant: .light))

                Text("Decide when the session turns off")
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)

                Toggle(isOn: $settingsStore.liveActivitiesEnabled) {
                    Text("Live Activities")
                        .font(.appFont(16, variant: .light))
                        .foregroundStyle(.white)
                }

                Text("Allow KeyVox to show live activity updates")
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var keyboardSection: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard")
                    .font(.appFont(17))
                    .foregroundStyle(.white)

                Toggle(isOn: $settingsStore.keyboardHapticsEnabled) {
                    Text("Keyboard haptics")
                        .font(.appFont(16, variant: .light))
                        .foregroundStyle(.white)
                }

                Text("Get haptic feedback from KeyVox Keyboard")
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio")
                    .font(.appFont(17))
                    .foregroundStyle(.white)

                Toggle(isOn: $settingsStore.preferBuiltInMicrophone) {
                    Text("Prefer Built-In Microphone")
                        .font(.appFont(16, variant: .light))
                        .foregroundStyle(.white)
                }

                Text(settingsStore.preferBuiltInMicrophone
                     ? "KeyVox will prefer the built-in microphone whenever one is available."
                     : "KeyVox will use the currently connected input device.")
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.appFont(17))
                    .foregroundStyle(.white)

                Text(modelManager.installState.statusText)
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)

                if let error = modelManager.errorMessage {
                    Text(error)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 8) {
                    switch modelManager.installState {
                    case .notInstalled:
                        Button("Download Model", action: modelManager.downloadModel)
                            .font(.appFont(14, variant: .light))
                    case .downloading, .installing:
                        if let actionText = modelManager.installState.actionText {
                            Text(actionText)
                                .font(.appFont(12))
                                .foregroundStyle(.secondary)
                        }
                    case .ready:
                        Button("Delete Model", action: modelManager.deleteModel)
                            .font(.appFont(14, variant: .light))
                    case .failed:
                        Button("Repair Model", action: modelManager.repairModelIfNeeded)
                            .font(.appFont(14, variant: .light))
                        Button("Delete Model", action: modelManager.deleteModel)
                            .font(.appFont(14, variant: .light))
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
