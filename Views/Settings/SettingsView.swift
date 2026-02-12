import SwiftUI

// MARK: - Main Settings View
struct SettingsView: View {
    static let preferredWindowSize = CGSize(width: 800, height: 600)
    @Environment(\.dismiss) var dismiss

    @ObservedObject internal var downloader = ModelDownloader.shared
    @StateObject internal var keyboardMonitor = KeyboardMonitor.shared
    @ObservedObject internal var audioDeviceManager = AudioDeviceManager.shared
    @State internal var selectedTab: SettingsTab = .general
    @State internal var showLegal = false

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
    }
    
    private var contentView: some View {
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
    }
}

#Preview {
    SettingsView()
}
