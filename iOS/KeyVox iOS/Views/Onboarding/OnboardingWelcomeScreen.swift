import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        AppScrollScreen {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 50)

                LogoBarView(size: 100)
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
                AppActionButton(
                    title: "Let's go",
                    style: .primary,
                    fillsWidth: true,
                    fontSize: 25,
                    action: onContinue
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppTheme.screenBackground.opacity(0.98))
        }
    }
}
