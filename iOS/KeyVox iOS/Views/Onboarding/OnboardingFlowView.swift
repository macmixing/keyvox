import SwiftUI

struct OnboardingFlowView: View {
    private enum Route: Equatable {
        case welcome
        case language
        case setup
        case keyboardTour
        case dictationShortcutSetup
    }

    @EnvironmentObject private var onboardingStore: OnboardingStore
    @State private var lastActiveRoute: Route = .welcome

    private var resolvedRoute: Route {
        if onboardingStore.isForceDictationShortcutSetupLaunch {
            return .dictationShortcutSetup
        } else if onboardingStore.shouldShowWelcomeScreen {
            return .welcome
        } else if onboardingStore.shouldShowLanguageSelectionScreen {
            return .language
        } else if onboardingStore.shouldShowKeyboardTourScreen {
            return .keyboardTour
        } else if onboardingStore.shouldShowDictationShortcutSetupScreen {
            return .dictationShortcutSetup
        } else {
            return .setup
        }
    }

    private var route: Route {
        onboardingStore.shouldShowOnboarding ? resolvedRoute : lastActiveRoute
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
                    removal: .scale(scale: 1.015)
                ))
            case .language:
                OnboardingLanguageScreen()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.015)
                    ))
            case .setup:
                OnboardingSetupScreen()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.015)
                    ))
            case .keyboardTour:
                OnboardingKeyboardTourScreen()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 1.015)
                    ))
            case .dictationShortcutSetup:
                DictationShortcutSetupOnboardingView {
                    onboardingStore.completeOnboarding()
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .scale(scale: 1.015)
                ))
            }
        }
        .onAppear {
            lastActiveRoute = resolvedRoute
        }
        .onChange(of: resolvedRoute, initial: false) { _, newValue in
            guard onboardingStore.shouldShowOnboarding else { return }
            lastActiveRoute = newValue
        }
        .animation(.easeInOut(duration: 0.34), value: route)
    }
}
