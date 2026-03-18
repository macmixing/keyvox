import SwiftUI

struct AppRootView: View {
    private enum RootDestination {
        case launchHold
        case returnToHost
        case onboarding
        case main
    }

    @EnvironmentObject private var appLaunchRouteStore: AppLaunchRouteStore
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var transcriptionManager: TranscriptionManager

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
            switch destination {
            case .launchHold:
                AppTheme.screenBackground
                    .ignoresSafeArea()
                    .transition(.opacity)
            case .returnToHost:
                ReturnToHostView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlowView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.34), value: destination)
    }
}

#Preview {
    AppRootView()
        .environmentObject(AppLaunchRouteStore.shared)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.onboardingStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
}
