import SwiftUI

// MARK: - Main Settings View
struct SettingsView: View {
    static let preferredWindowSize = CGSize(width: 800, height: 600)
    @Environment(\.dismiss) var dismiss

    @StateObject internal var appSettings = AppSettingsStore.shared
    @ObservedObject internal var downloader = ModelDownloader.shared
    @ObservedObject internal var audioDeviceManager = AudioDeviceManager.shared
    @ObservedObject internal var dictionaryStore = DictionaryStore.shared
    @State internal var selectedTab: SettingsTab
    @State internal var showLegal = false
    @State internal var dictionaryEditorMode: DictionaryWordEditorMode?
    @State internal var dictionaryDeleteTarget: DictionaryEntry?

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            // Background
            Color.indigo.opacity(0.15)
                .background(Color(white: 0.01))
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                
                // Content Area
                contentView
            }
            
            // Close Button (Fixed at top right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { NSApp.keyWindow?.orderOut(nil) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 15)
                }
                Spacer()
            }
        }
        .frame(width: Self.preferredWindowSize.width, height: Self.preferredWindowSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLegal) {
            LegalView()
        }
        .sheet(item: $dictionaryEditorMode) { mode in
            DictionaryWordEditorView(mode: mode, dictionaryStore: dictionaryStore)
        }
        .sheet(item: $dictionaryDeleteTarget) { entry in
            ConfirmDeletePromptView(
                config: ConfirmDeletePromptConfig(
                    title: "Delete Entry?",
                    message: "This dictionary entry will be removed from KeyVox."
                ),
                onConfirm: {
                    dictionaryStore.delete(id: entry.id)
                    dictionaryDeleteTarget = nil
                },
                onCancel: {
                    dictionaryDeleteTarget = nil
                }
            )
        }
        .onAppear {
            appSettings.refreshWeeklyWordCounterIfNeeded()
        }
    }
    
    private var contentView: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    switch selectedTab {
                    case .general:
                        generalSettings
                    case .audio:
                        audioSettings
                    case .model:
                        modelSettings
                    case .information:
                        informationSettings
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if selectedTab == .information {
                Text("Version \(appVersion)")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.trailing, 32)
                    .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    SettingsView()
}
