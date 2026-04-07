import SwiftUI

extension SettingsView {
    var homeSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 4)

            weeklyWordsCard
            lastTranscriptionCard
            keyVoxiPhonePromoCard
        }
    }

    private var weeklyWordsCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {

                VStack(alignment: .center, spacing: -4) {
                    Text(weeklyWordStatsStore.combinedWordCount.formatted())
                        .font(.appFont(65))
                        .fontWeight(.heavy)
                        .foregroundColor(.yellow)

                    Text("Words this week!")
                        .font(.appFont(16))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
    }

    private var lastTranscriptionCard: some View {
        SettingsLastTranscriptionCard(text: transcriptionManager.lastTranscription)
    }

    private var keyVoxiPhonePromoCard: some View {
        DeveloperLinkCard(
            icon: .appBundleIcon,
            title: "Get KeyVox Keyboard for iPhone",
            subtitle: "The same great KeyVox dictation is available on iPhone with a keyboard experience built for iOS.",
            buttonTitle: "Download",
            copyLink: "https://apps.apple.com/us/app/keyvox-ai-voice-keyboard/id6760396964?ct=mac-settings-ios-copy-link&mt=8",
            isPromoted: true
        ) {
            guard let url = URL(string: "https://apps.apple.com/us/app/keyvox-ai-voice-keyboard/id6760396964?ct=mac-settings-ios-promo&mt=8") else { return }
            NSWorkspace.shared.open(url)
        }
    }
}
