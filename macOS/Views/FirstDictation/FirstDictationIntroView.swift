import Foundation
import SwiftUI

struct FirstDictationIntroView: View {
    let onTry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 42)

            LogoBarView(size: 88)

            VStack(spacing: 8) {
                Text("Try your first dictation", comment: "Title of the first dictation practice screen shown after onboarding.")
                    .font(.appFont(30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Practice once now, or skip and start using KeyVox.", comment: "Subtitle of the first dictation practice screen. KeyVox is a brand name and stays in English.")
                    .font(.appFont(15, variant: .light))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: 340)
            }

            Spacer()

            VStack(spacing: 12) {
                AppActionButton(
                    title: String(localized: "Try It", comment: "Button on the first dictation screen that starts the dictation practice."),
                    style: .primary,
                    minWidth: 220,
                    action: onTry
                )

                AppActionButton(
                    title: String(localized: "Skip", comment: "Button on the first dictation screen that skips the dictation practice."),
                    style: .secondary,
                    minWidth: 220,
                    action: onSkip
                )
            }
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 50)
    }
}
