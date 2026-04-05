import SwiftUI

struct MainTabView: View {
    enum Edge {
        case leading
        case trailing
    }

    private enum Swipe {
        static let minimumDistance: CGFloat = 20
        static let threshold: CGFloat = 50
        static let edgeInset: CGFloat = 24
    }

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject private var appTabRouter: AppTabRouter
    @State private var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 26.0, *) {
                    tabContent
                        .tabBarMinimizeBehavior(.automatic)
                        .tint(.indigo)
                } else {
                    tabContent
                        .tint(.indigo)
                }
            }
            .navigationTitle(selectedTab == .home ? "" : selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppToolbarContent(selectedTab: selectedTab)
            }
        }
        .settingsDeletionConfirmation($pendingDeletionConfirmation, onConfirm: performDeletionConfirmation)
        .sheet(
            isPresented: Binding(
                get: { ttsPurchaseController.isUnlockSheetPresented },
                set: { isPresented in
                    if isPresented == false {
                        ttsPurchaseController.dismissUnlockSheet()
                    }
                }
            )
        ) {
            TTSUnlockSheetView()
                .environmentObject(ttsPurchaseController)
        }
        .onChange(of: selectedTab, initial: false) { oldTab, newTab in
            if let event = MainTabHapticsDecision.eventForSelectionChange(previous: oldTab, current: newTab) {
                appHaptics.emit(event)
            }
        }
    }

    private var tabContent: some View {
        TabView(selection: $appTabRouter.selectedTab) {
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(ContainingAppTab.home)

            DictionaryTabView(isActive: selectedTab == .dictionary)
                .tabItem {
                    Label("Dictionary", systemImage: "text.book.closed.fill")
                }
                .tag(ContainingAppTab.dictionary)

            StyleTabView()
                .tabItem {
                    Label("Style", systemImage: "scribble.variable")
                }
                .tag(ContainingAppTab.style)

            SettingsTabView(pendingDeletionConfirmation: $pendingDeletionConfirmation)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(ContainingAppTab.settings)
        }
        .overlay(alignment: .leading) {
            edgeSwipeCatcher(for: .leading)
        }
        .overlay(alignment: .trailing) {
            edgeSwipeCatcher(for: .trailing)
        }
    }

    private func edgeSwipeCatcher(for edge: Edge) -> some View {
        Color.clear
            .frame(width: Swipe.edgeInset)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: Swipe.minimumDistance)
                    .onEnded { value in
                        handleTabSwipe(value, edge: edge)
                    }
            )
    }

    private func handleTabSwipe(_ value: DragGesture.Value, edge: Edge) {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        guard abs(horizontalDistance) > abs(verticalDistance) else {
            return
        }

        if edge == .trailing,
           horizontalDistance <= -Swipe.threshold,
           let nextTab = selectedTab.next {
            appTabRouter.selectedTab = nextTab
        } else if edge == .leading,
                  horizontalDistance >= Swipe.threshold,
                  let previousTab = selectedTab.previous {
            appTabRouter.selectedTab = previousTab
        } else if let event = MainTabHapticsDecision.eventForEdgeSwipeAttempt(
            currentTab: selectedTab,
            edge: edge,
            horizontalDistance: horizontalDistance
        ) {
            appHaptics.emit(event)
        }
    }

    private func performDeletionConfirmation(_ confirmation: SettingsPendingDeletionConfirmation) {
        switch confirmation {
        case .dictationModel(let modelID):
            modelManager.deleteModel(withID: modelID)
        case .sharedTTSModel:
            pocketTTSModelManager.deleteSharedModel()
        case .ttsVoice(let voice):
            pocketTTSModelManager.deleteVoice(voice)
        }
    }

    private var selectedTab: ContainingAppTab {
        appTabRouter.selectedTab
    }

}

#Preview {
    MainTabView()
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.appTabRouter)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
        .environmentObject(AppServiceRegistry.shared.audioModeCoordinator)
        .environmentObject(AppServiceRegistry.shared.ttsManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
}
