import SwiftUI

enum SettingsTabCopy {
    enum Keyboard {
        static let hapticsTitle = "Keyboard Haptics"
        static let hapticsDescription = "Get haptic feedback from KeyVox Keyboard."
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
                    .background(.white.opacity(0.4))

                SettingsRow(
                    icon: "widget.small",
                    title: "Live Activities",
                    description: "Allow KeyVox to show live activity updates.",
                    isOn: $settingsStore.liveActivitiesEnabled
                )
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

                Text("Decide how long KeyVox Speak stays ready to buffer playback.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    var keyboardSection: some View {
        AppCard {
            SettingsRow(
                icon: "keyboard",
                title: SettingsTabCopy.Keyboard.hapticsTitle,
                description: SettingsTabCopy.Keyboard.hapticsDescription,
                isOn: $settingsStore.keyboardHapticsEnabled
            )
        }
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
