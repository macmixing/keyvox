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
                Button(action: {
                    onboardingStore.completeOnboarding()
                }) {
                    Text("Finish")
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
