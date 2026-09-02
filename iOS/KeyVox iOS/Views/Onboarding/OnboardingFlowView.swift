import SwiftUI

struct OnboardingFlowView: View {
    private enum Route: Hashable {
        case welcome
        case language
        case setup
        case keyboardSetup
        case keyboardTour
        case dictationShortcutSetup
    }

    @EnvironmentObject private var onboardingStore: OnboardingStore
    @State private var routeStack: [Route] = []
    @State private var hasRequestedShortcutInstallation = false
    @State private var hasRequestedSettings = false

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
        } else if onboardingStore.shouldShowKeyboardSetupScreen {
            return .keyboardSetup
        } else {
            return .setup
        }
    }

    private var displayedRoutes: [Route] {
        routeStack.isEmpty ? [resolvedRoute] : routeStack
    }

    private var initialRouteStack: [Route] {
        if resolvedRoute == .keyboardSetup {
            return [.dictationShortcutSetup, .keyboardSetup]
        }

        return [resolvedRoute]
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            ForEach(Array(displayedRoutes.enumerated()), id: \.element) { index, route in
                screen(for: route)
                    .allowsHitTesting(route == displayedRoutes.last)
                    .accessibilityHidden(route != displayedRoutes.last)
                    .transition(.move(edge: .trailing))
                    .zIndex(Double(index))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            guard routeStack.isEmpty else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                routeStack = initialRouteStack
            }
        }
        .onChange(of: resolvedRoute, initial: false) { _, newValue in
            guard onboardingStore.shouldShowOnboarding else { return }
            updateRouteStack(for: newValue)
        }
        .animation(.easeInOut(duration: 0.34), value: routeStack)
    }

    @ViewBuilder
    private func screen(for route: Route) -> some View {
        switch route {
        case .welcome:
            OnboardingWelcomeScreen {
                onboardingStore.completeWelcomeScreen()
            }
        case .language:
            OnboardingLanguageScreen()
        case .setup:
            OnboardingSetupScreen()
        case .dictationShortcutSetup:
            DictationShortcutSetupOnboardingView(
                initialPage: routeStack.contains(.keyboardSetup)
                    ? .actionButtonDemoHandoff
                    : .shortcutIntro,
                hasRequestedShortcutInstallation: $hasRequestedShortcutInstallation,
                hasRequestedSettings: $hasRequestedSettings,
                onReturnToSetup: {
                    onboardingStore.returnToSetupFromDictationShortcutSetup()
                },
                onContinueToKeyboardSetup: {
                    onboardingStore.continueToKeyboardSetup()
                }
            )
        case .keyboardSetup:
            OnboardingEnableKeyboardScreen()
        case .keyboardTour:
            OnboardingKeyboardTourScreen()
        }
    }

    private func updateRouteStack(for route: Route) {
        if let existingIndex = routeStack.firstIndex(of: route) {
            routeStack.removeSubrange(routeStack.index(after: existingIndex)...)
        } else {
            routeStack.append(route)
        }
    }
}
