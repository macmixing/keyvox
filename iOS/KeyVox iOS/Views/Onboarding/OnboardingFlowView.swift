import SwiftUI

struct OnboardingFlowView: View {
    private enum Screen {
        case welcome
        case setup
    }

    @State private var screen: Screen = .welcome

    var body: some View {
        switch screen {
        case .welcome:
            OnboardingWelcomeScreen {
                screen = .setup
            }
        case .setup:
            OnboardingSetupScreen()
        }
    }
}
