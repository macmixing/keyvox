import SwiftUI

struct KeyVoxSpeakSceneCView: View {
    let showsUnlockDetails: Bool
    let purchaseSummaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Designed To Grow")
                .font(.appFont(26))
                .foregroundStyle(.white)

            Text("This intro is intentionally lightweight for now while the final KeyVox Speak presentation is still being designed.")
                .font(.appFont(16, variant: .light))
                .foregroundStyle(.white.opacity(0.78))

            if showsUnlockDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Two free speaks per day")
                    Text("Replay stays free for anything already generated")
                    Text(purchaseSummaryText)
                }
                .font(.appFont(14, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }
}
