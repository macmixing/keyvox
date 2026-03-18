import SwiftUI

struct OnboardingFlowView: View {
    private enum Route: Equatable {
        case welcome
        case setup
        case keyboardTour
    }

    @EnvironmentObject private var onboardingStore: OnboardingStore

    private var route: Route {
        if onboardingStore.shouldShowWelcomeScreen {
            return .welcome
        } else if onboardingStore.shouldShowKeyboardTourScreen {
            return .keyboardTour
        } else {
            return .setup
        }
    }

    var body: some View {
        ZStack {
            switch route {
            case .welcome:
                OnboardingWelcomeScreen {
                    onboardingStore.completeWelcomeScreen()
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.985)),
                    removal: .opacity.combined(with: .offset(y: -24))
                ))
            case .setup:
                OnboardingSetupScreen()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 20)),
                        removal: .opacity.combined(with: .scale(scale: 1.015))
                    ))
            case .keyboardTour:
                OnboardingKeyboardTourScreen()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.34), value: route)
    }
}
