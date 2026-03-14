import SwiftUI

struct AppRootView: View {
    private enum RootDestination {
        case main
    }

    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager

    private var destination: RootDestination {
        .main
    }

    var body: some View {
        if transcriptionManager.isReturnToHostViewPresented {
            ReturnToHostView()
        } else {
            switch destination {
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
        .environmentObject(iOSAppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
