import SwiftUI
import KeyVoxPromotions

extension SettingsView {
    var homeSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 4)

            weeklyWordsCard
            lastTranscriptionCard
            promotionCard
        }
        .animation(.easeInOut(duration: 0.2), value: promotionCenter.currentCampaign?.id)
    }

    private var weeklyWordsCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {

                VStack(alignment: .center, spacing: -4) {
                    Text(verbatim: AppTypography.fontSupportedSpacing(weeklyWordStatsStore.combinedWordCount.formatted()))
                        .font(.appFont(65))
                        .fontWeight(.heavy)
                        .foregroundColor(.yellow)

                    Text("Words this week!", comment: "Label under the large weekly word count on the Home page in Settings. The number is shown separately above this label.")
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

    @ViewBuilder
    private var promotionCard: some View {
        if let campaign = promotionCenter.currentCampaign {
            MacPromotionCard(campaign: campaign)
                .transition(.opacity)
        }
    }
}
