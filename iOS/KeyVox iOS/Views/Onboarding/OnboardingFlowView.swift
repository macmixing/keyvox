import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var onboardingStore: iOSOnboardingStore

    var body: some View {
        if onboardingStore.shouldShowWelcomeScreen {
            OnboardingWelcomeScreen {
                onboardingStore.completeWelcomeScreen()
            }
        } else if onboardingStore.shouldShowCustomizeAppScreen {
            OnboardingCustomizeAppScreen()
        } else if onboardingStore.shouldShowKeyboardTourScreen {
            OnboardingKeyboardTourScreen()
        } else {
            OnboardingSetupScreen()
        }
    }
}
