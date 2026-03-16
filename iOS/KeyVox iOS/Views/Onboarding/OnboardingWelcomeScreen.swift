import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        iOSAppScrollScreen {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 50)

                iOSLogoBarView(size: 100)
                    .padding(.bottom, 32)

                Text("Welcome to KeyVox")
                    .font(.appFont(34, variant: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Free Your Voice")
                    .font(.appFont(22, variant: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: onContinue) {
                    Text("Let's go")
                        .font(.appFont(18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(.yellow)
                .foregroundStyle(.black)
            }
            .padding(.horizontal, iOSAppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(iOSAppTheme.screenBackground.opacity(0.98))
        }
    }
}
