import SwiftUI

struct OnboardingCustomizeAppScreen: View {
    @EnvironmentObject private var onboardingStore: iOSOnboardingStore

    var body: some View {
        iOSAppScrollScreen {
            VStack(alignment: .leading, spacing: 24) {
                Text("Customize KeyVox")
                    .font(.appFont(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                iOSAppActionButton(
                    title: "Finish",
                    style: .primary,
                    fillsWidth: true,
                    fontSize: 25,
                    action: onboardingStore.completeOnboarding
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, iOSAppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(iOSAppTheme.screenBackground.opacity(0.98))
        }
    }
}
