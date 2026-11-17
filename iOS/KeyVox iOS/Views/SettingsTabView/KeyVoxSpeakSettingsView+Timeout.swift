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
                        Text("Speak Timeout", comment: "Title of the KeyVox Speak setting that chooses how long the engine stays ready. Speak is a brand name and stays in English.")
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
                        Text("Change", comment: "Menu button that opens the choices for the Speak timeout.")
                            .font(.appFont(16))
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 2)
                }

                Text("Decide how long KeyVox Speak stays ready to start loading audio.", comment: "Description under the Speak Timeout setting. KeyVox Speak is a brand name and stays in English.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
