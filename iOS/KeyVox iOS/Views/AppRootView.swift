import SwiftUI

struct AppRootView: View {
    private enum RootDestination {
        case onboarding
        case main
    }

    @EnvironmentObject private var onboardingStore: iOSOnboardingStore
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager

    private var destination: RootDestination {
        onboardingStore.shouldShowOnboarding ? .onboarding : .main
    }

    var body: some View {
        if transcriptionManager.isReturnToHostViewPresented {
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
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.modelManager)
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
        .environmentObject(iOSAppServiceRegistry.shared.onboardingStore)
        .environmentObject(iOSAppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
