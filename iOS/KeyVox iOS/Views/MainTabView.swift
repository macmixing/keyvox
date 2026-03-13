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
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager

    private var isSessionEnabled: Bool {
        transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending
    }

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
                if selectedTab == .home {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            iOSLogoBarView(size: 32)
                            Text("KeyVox")
                                .font(.appFont(28))
                                .foregroundColor(.indigo)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        sessionToggleView
                    }
                }
            }
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

    private var sessionToggleView: some View {
        Group {
            if #available(iOS 26.0, *) {
                if isSessionEnabled {
                    sessionToggleButton
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .tint(.indigo.opacity(0.5))
                } else {
                    sessionToggleButton
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .tint(.white.opacity(0.001))
                }
            } else {
                sessionToggleButton
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(isSessionEnabled ? .indigo.opacity(0.5) : .gray.opacity(0.25))
            }
        }
    }

    private var sessionToggleButton: some View {
        Button(action: {
            if isSessionEnabled {
                transcriptionManager.handleDisableSessionCommand()
            } else {
                transcriptionManager.handleEnableSessionCommand()
            }
        }) {
            Image("logo-white-ios")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
    }

    private var sessionToggleBinding: Binding<Bool> {
        Binding(
            get: { transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending },
            set: { isEnabled in
                if isEnabled {
                    transcriptionManager.handleEnableSessionCommand()
                } else {
                    transcriptionManager.handleDisableSessionCommand()
                }
            }
        )
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
