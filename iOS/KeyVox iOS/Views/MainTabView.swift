import SwiftUI

struct MainTabView: View {
    private enum Edge {
        case leading
        case trailing
    }

    private enum Swipe {
        static let minimumDistance: CGFloat = 20
        static let threshold: CGFloat = 50
        static let edgeInset: CGFloat = 24
    }

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

            SettingsTabView()
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
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = nextTab
            }
        } else if edge == .leading,
                  horizontalDistance >= Swipe.threshold,
                  let previousTab = selectedTab.previous {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = previousTab
            }
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
