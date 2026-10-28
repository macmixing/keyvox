import SwiftUI

extension SettingsTabView {
    @ViewBuilder
    var dictationSection: some View {
        Button {
            dictationModelSectionExpansionRequestID = nil
            isDictationSettingsPresented = true
        } label: {
            AppCard {
                HStack(alignment: .center, spacing: 12) {
                    SettingsRow(
                        icon: "waveform",
                        title: DictationSettingsCopy.screenTitle,
                        description: DictationSettingsCopy.screenDescription
                    ) {
                        EmptyView()
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.yellow)
                        .frame(width: 56)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var keyVoxSpeakSection: some View {
        NavigationLink {
            KeyVoxSpeakSettingsView(
                pendingDeletionConfirmation: $pendingDeletionConfirmation,
                pendingDownloadConfirmation: $pendingDownloadConfirmation
            )
        } label: {
            AppCard {
                HStack(alignment: .center, spacing: 12) {
                    SettingsRow(
                        icon: "speaker.wave.2.fill",
                        title: KeyVoxSpeakSettingsCopy.screenTitle,
                        description: KeyVoxSpeakSettingsCopy.screenDescription
                    ) {
                        EmptyView()
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.yellow)
                        .frame(width: 56)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var keyboardSection: some View {
        NavigationLink {
            KeyboardSettingsView(pendingDeletionConfirmation: $pendingDeletionConfirmation)
        } label: {
            AppCard {
                HStack(alignment: .center, spacing: 12) {
                    SettingsRow(
                        icon: "keyboard",
                        title: KeyboardSettingsCopy.screenTitle,
                        description: KeyboardSettingsCopy.screenDescription
                    ) {
                        EmptyView()
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.yellow)
                        .frame(width: 56)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
