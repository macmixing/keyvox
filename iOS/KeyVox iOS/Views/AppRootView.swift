import SwiftUI

struct AppRootView: View {
    private enum RootDestination {
        case onboarding
        case main
    }

    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var transcriptionManager: TranscriptionManager

    private var destination: RootDestination {
        onboardingStore.shouldShowOnboarding ? .onboarding : .main
    }

    private var shouldShowReturnToHostView: Bool {
        !onboardingStore.shouldSuppressReturnToHostView && transcriptionManager.isReturnToHostViewPresented
    }

    var body: some View {
        if shouldShowReturnToHostView {
            ReturnToHostView()
        } else {
            switch destination {
            case .onboarding:
                OnboardingFlowView()
            case .main:
                MainTabView()
            }
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.onboardingStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
}
