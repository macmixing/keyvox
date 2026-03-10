import SwiftUI

struct MainTabView: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                tabContent
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .tint(.indigo)
            } else {
                tabContent
                    .toolbarBackground(.visible, for: .tabBar)
                    .toolbarBackground(.regularMaterial, for: .tabBar)
                    .tint(.indigo)
            }
        }
    }

    private var tabContent: some View {
        TabView {
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            DictionaryTabView()
                .tabItem {
                    Label("Dictionary", systemImage: "text.book.closed.fill")
                }

            StyleTabView()
                .tabItem {
                    Label("Style", systemImage: "scribble.variable")
                }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.modelManager)
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
