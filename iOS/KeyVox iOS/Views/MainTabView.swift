import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: ContainingAppTab = .home

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 26.0, *) {
                    tabContent
                        .tabBarMinimizeBehavior(.automatic)
                        .tint(.indigo)
                } else {
                    tabContent
                        .toolbarBackground(.visible, for: .tabBar)
                        .toolbarBackground(.regularMaterial, for: .tabBar)
                        .tint(.indigo)
                }
            }
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(ContainingAppTab.home)

            DictionaryTabView()
                .tabItem {
                    Label("Dictionary", systemImage: "text.book.closed.fill")
                }
                .tag(ContainingAppTab.dictionary)

            StyleTabView()
                .tabItem {
                    Label("Style", systemImage: "scribble.variable")
                }
                .tag(ContainingAppTab.style)

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(ContainingAppTab.settings)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.modelManager)
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
        .environmentObject(iOSAppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
