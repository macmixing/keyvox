import SwiftUI

struct OnboardingCustomizeAppScreen: View {
    @EnvironmentObject private var onboardingStore: iOSOnboardingStore

    var body: some View {
        OnboardingScreenScaffold(
            title: "Customize KeyVox",
            actionTitle: "Finish",
            action: {
                onboardingStore.completeOnboarding()
            }
        ) {
            EmptyView()
        }
    }
}
