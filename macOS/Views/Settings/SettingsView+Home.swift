import SwiftUI

extension SettingsView {
    var homeSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 4)

            weeklyWordsCard
            lastTranscriptionCard
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
}
