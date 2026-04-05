import SwiftUI

struct AppRootView: View {
    private enum RootDestination: Equatable {
        case launchHold
        case returnToHost
        case playbackPreparation
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
    @EnvironmentObject private var ttsManager: TTSManager
    @State private var previousDestination: RootDestination?
    @State private var onboardingOverlayState: RootOverlayState = .hidden
    @State private var onboardingOverlayOpacity = 1.0

    private var destination: RootDestination {
        if !appLaunchRouteStore.hasResolvedInitialLaunchContext {
            return .launchHold
        }

        if ttsManager.isPlaybackPreparationViewPresented {
            return .playbackPreparation
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
                case .playbackPreparation:
                    PlaybackPreparationView()
                        .transition(rootTransition)
                case .onboarding, .main:
                    EmptyView()
                }
            }
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

}

#Preview {
    AppRootView()
        .environmentObject(AppLaunchRouteStore.shared)
        .environmentObject(AppServiceRegistry.shared.audioModeCoordinator)
        .environmentObject(AppServiceRegistry.shared.appTabRouter)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.ttsManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.onboardingStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
}
