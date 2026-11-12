import Foundation
import SwiftUI

extension DictationSettingsView {
    @ViewBuilder
    var sessionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.4))
                                .frame(width: 32, height: 32)

                            Image(systemName: "clock")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yellow)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dictation Timeout", comment: "Title of the setting that chooses when the dictation session turns off.")
                                .font(.appFont(18))
                                .foregroundStyle(.white)

                            Text(settingsStore.sessionDisableTiming.displayName)
                                .font(.appFont(17))
                                .foregroundStyle(.yellow)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Menu {
                            Picker("", selection: $settingsStore.sessionDisableTiming) {
                                ForEach(SessionDisableTiming.allCases) { timing in
                                    Text(timing.displayName).tag(timing)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Text("Change", comment: "Menu button that opens the choices for the dictation timeout.")
                                .font(.appFont(16))
                                .foregroundColor(.yellow)
                        }
                        .padding(.top, 2)
                    }

                    Text("Decide when the dictation session turns off.", comment: "Description under the Dictation Timeout setting.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                SettingsRow(
                    icon: "widget.small",
                    title: String(localized: "Live Activities", comment: "Dictation settings toggle. Use Apple's official name for Live Activities in this language."),
                    description: String(localized: "Allow KeyVox to show live activity updates. Required for the Dictation Shortcut.", comment: "Description under the Live Activities toggle. KeyVox is a brand name and stays in English; use Apple's official term for live activities in this language. Dictation Shortcut is the name of the KeyVox setting below it."),
                    isOn: $settingsStore.liveActivitiesEnabled
                )

                Divider()
                    .overlay(.white.opacity(0.22))

                SettingsRow(
                    assetIcon: "keyvox-circle",
                    title: String(localized: "Dictation Shortcut", comment: "Dictation settings row for setting up a shortcut that turns KeyVox dictation on or off."),
                    description: String(localized: "Add a quick shortcut to toggle KeyVox dictation anywhere.", comment: "Description under the Dictation Shortcut row. KeyVox is a brand name and stays in English.")
                ) {
                    AppActionButton(
                        title: String(localized: "Set Up", comment: "Button on the Dictation Shortcut row that opens the shortcut setup guide."),
                        style: .primary,
                        size: .compact,
                        fontSize: 15
                    ) {
                        dictationShortcutSetupIntroController.markHandled()
                        isDictationShortcutSetupPresented = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    var audioSection: some View {
        AppCard {
            SettingsRow(
                icon: "mic.fill",
                title: String(localized: "Prefer Built-In Microphone", comment: "Dictation settings toggle that makes KeyVox use the device's own microphone."),
                description: settingsStore.preferBuiltInMicrophone
                    ? String(localized: "KeyVox will prefer the built-in microphone whenever one is available.", comment: "Description under the Prefer Built-In Microphone toggle when it is on. KeyVox is a brand name and stays in English.")
                    : String(localized: "KeyVox will use the currently connected input device.", comment: "Description under the Prefer Built-In Microphone toggle when it is off. KeyVox is a brand name and stays in English."),
                isOn: $settingsStore.preferBuiltInMicrophone
            )
        }
    }
}
