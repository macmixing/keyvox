import SwiftUI

struct AppRootView: View {
    private enum RootDestination: Equatable {
        case launchHold
        case returnToHost
        case onboarding
        case main
    }

    private enum RootOverlayState {
        case hidden
        case visible
    }

    @EnvironmentObject private var appLaunchRouteStore: AppLaunchRouteStore
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @EnvironmentObject private var appUpdateCoordinator: AppUpdateCoordinator
    @State private var previousDestination: RootDestination?
    @State private var onboardingOverlayState: RootOverlayState = .hidden
    @State private var onboardingOverlayOpacity = 1.0

    private var destination: RootDestination {
        if !appLaunchRouteStore.hasResolvedInitialLaunchContext {
            return .launchHold
        }

        if !onboardingStore.shouldSuppressReturnToHostView
            && (
                transcriptionManager.isReturnToHostViewPresented
                    || appLaunchRouteStore.initialURLRoute == .startRecording
            ) {
            return .returnToHost
        }

        return onboardingStore.shouldShowOnboarding ? .onboarding : .main
    }

    var body: some View {
        ZStack {
            if destination == .onboarding || destination == .main {
                MainTabView()

                if onboardingOverlayState == .visible || destination == .onboarding {
                    OnboardingFlowView()
                        .opacity(onboardingOverlayOpacity)
                }
            } else {
                switch destination {
                case .launchHold:
                    AppTheme.screenBackground
                        .ignoresSafeArea()
                        .transition(rootTransition)
                case .returnToHost:
                    ReturnToHostView()
                        .transition(rootTransition)
                case .onboarding, .main:
                    EmptyView()
                }
            }
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { shouldPresentUpdateAlert },
                set: { isPresented in
                    if isPresented == false,
                       destination == .main,
                       appUpdateCoordinator.activePrompt?.decision.urgency == .optional {
                        appUpdateCoordinator.dismissOptionalPrompt()
                    }
                }
            )
        ) {
            Button("Update") {
                appUpdateCoordinator.openAppStore()
            }

            if appUpdateCoordinator.activePrompt?.decision.urgency == .optional {
                Button("Later", role: .cancel) {
                    appUpdateCoordinator.dismissOptionalPrompt()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            previousDestination = destination
            onboardingOverlayState = destination == .onboarding ? .visible : .hidden
            onboardingOverlayOpacity = 1
        }
        .onChange(of: destination, initial: false) { oldValue, newValue in
            previousDestination = oldValue

            if newValue == .onboarding {
                onboardingOverlayState = .visible
                onboardingOverlayOpacity = 1
            } else if oldValue == .onboarding && newValue == .main {
                withAnimation(.easeInOut(duration: 0.34)) {
                    onboardingOverlayOpacity = 0
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(340))
                    if destination == .main {
                        onboardingOverlayState = .hidden
                        onboardingOverlayOpacity = 1
                    }
                }
            } else {
                onboardingOverlayState = .hidden
                onboardingOverlayOpacity = 1
            }
        }
        .animation(rootAnimation, value: destination)
    }

    private var rootTransition: AnyTransition {
        shouldSkipRootTransition ? .identity : .opacity
    }

    private var rootAnimation: Animation? {
        shouldSkipRootTransition ? nil : .easeInOut(duration: 0.34)
    }

    private var shouldSkipRootTransition: Bool {
        previousDestination == .launchHold
            && (destination == .onboarding || destination == .main)
    }
    private var shouldPresentUpdateAlert: Bool {
        destination == .main && appUpdateCoordinator.activePrompt != nil
    }

    private var alertTitle: String {
        guard let prompt = appUpdateCoordinator.activePrompt else { return "" }

        switch prompt.decision.urgency {
        case .optional:
            return "Update Available"
        case .forced:
            return "Update Required"
        }
    }

    private var alertMessage: String {
        guard let prompt = appUpdateCoordinator.activePrompt else { return "" }

        switch prompt.decision.urgency {
        case .optional:
            return "KeyVox \(prompt.decision.release.version.rawValue) is available on the App Store."
        case .forced:
            return "KeyVox \(prompt.decision.release.version.rawValue) is required to continue using the app."
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(AppLaunchRouteStore.shared)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.appUpdateCoordinator)
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.onboardingStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
}
