import SwiftUI

struct FirstDictationIntroView: View {
    let onTry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 42)

            LogoBarView(size: 88)

            VStack(spacing: 8) {
                Text("Try your first dictation")
                    .font(.appFont(30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Practice once now, or skip and start using KeyVox.")
                    .font(.appFont(15, variant: .light))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Spacer()

            VStack(spacing: 12) {
                AppActionButton(
                    title: "Try It",
                    style: .primary,
                    minWidth: 220,
                    action: onTry
                )

                AppActionButton(
                    title: "Skip",
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
