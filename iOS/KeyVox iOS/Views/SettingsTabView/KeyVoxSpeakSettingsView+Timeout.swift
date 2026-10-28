import SwiftUI

extension KeyVoxSpeakSettingsView {
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
}
