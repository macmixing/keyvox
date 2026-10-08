import SwiftUI

enum SettingsTabCopy {
    enum Keyboard {
        static let screenTitle = "Keyboard"
        static let screenDescription = "Typing helps, corrections, and layout for the KeyVox keyboard."
        static let autoCapitalizationTitle = "Auto-Capitalization"
        static let autoCorrectionTitle = "Auto-Correction"
        static let capsLockTitle = "Enable Caps Lock"
        static let predictiveTextTitle = "Predictive Text"
        static let periodShortcutTitle = "“.” Shortcut"
        static let periodShortcutDescription = "Double tap the space bar to type a period followed by a space."
        static let hapticsTitle = "Keyboard Haptics"
        static let hapticsDescription = "Get haptic feedback from KeyVox keyboard."
        static let leftHandedLayoutTitle = "Left-Handed Layout"
        static let leftHandedLayoutDescription = "Mirror KeyVox controls for easier left-hand access."
        static let compactKeysTitle = "Compact Keys"
        static let compactKeysDescription = "Long-press #+= to use a shorter keyboard."
    }
}

extension SettingsTabView {
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
                            Text("Dictation Timeout")
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
                            Text("Change")
                                .font(.appFont(16))
                                .foregroundColor(.yellow)
                        }
                        .padding(.top, 2)
                    }

                    Text("Decide when the dictation session turns off.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                SettingsRow(
                    icon: "widget.small",
                    title: "Live Activities",
                    description: "Allow KeyVox to show live activity updates. Required for the Dictation Shortcut.",
                    isOn: $settingsStore.liveActivitiesEnabled
                )

                Divider()
                    .overlay(.white.opacity(0.22))

                SettingsRow(
                    assetIcon: "keyvox-circle",
                    title: "Dictation Shortcut",
                    description: "Add a quick shortcut to toggle KeyVox dictation anywhere."
                ) {
                    AppActionButton(
                        title: "Set Up",
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
    var speakTimeoutSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "speaker.zzz.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speak Timeout")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.speakTimeoutTiming.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Picker("", selection: $settingsStore.speakTimeoutTiming) {
                            ForEach(SpeakTimeoutTiming.allCases) { timing in
                                Text(timing.displayName).tag(timing)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Text("Change")
                            .font(.appFont(16))
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 2)
                }

                Text("Decide how long KeyVox Speak stays ready to start loading audio.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    var keyboardSection: some View {
        NavigationLink {
            KeyboardSettingsView()
        } label: {
            AppCard {
                SettingsRow(
                    icon: "keyboard",
                    title: SettingsTabCopy.Keyboard.screenTitle,
                    description: SettingsTabCopy.Keyboard.screenDescription
                ) {
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
    var audioSection: some View {
        AppCard {
            SettingsRow(
                icon: "mic.fill",
                title: "Prefer Built-In Microphone",
                description: settingsStore.preferBuiltInMicrophone
                    ? "KeyVox will prefer the built-in microphone whenever one is available."
                    : "KeyVox will use the currently connected input device.",
                isOn: $settingsStore.preferBuiltInMicrophone
            )
        }
    }
}
