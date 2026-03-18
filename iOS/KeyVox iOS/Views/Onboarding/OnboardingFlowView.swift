import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var onboardingStore: OnboardingStore

    var body: some View {
        if onboardingStore.shouldShowWelcomeScreen {
            OnboardingWelcomeScreen {
                onboardingStore.completeWelcomeScreen()
            }
        } else if onboardingStore.shouldShowKeyboardTourScreen {
            OnboardingKeyboardTourScreen()
        } else {
            OnboardingSetupScreen()
        }
    }
}
