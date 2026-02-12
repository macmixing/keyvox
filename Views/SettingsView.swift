import SwiftUI

// MARK: - Animated Wave Header with Circle
struct AnimatedWaveHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            KeyVoxLogo()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("KeyVox")
                    .font(.custom("Kanit Medium", size: 24))
                    .foregroundColor(.indigo)
                Text("Local.  Private. Fast.")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }
        }
    }
}

// MARK: - Modern Settings Components
struct SettingsCard<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let accessory: Accessory
    
    init(icon: String, title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.custom("Kanit Medium", size: 20))
                    .foregroundColor(.indigo)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Kanit Medium", size: 17))
                
                Text(subtitle)
                    .font(.custom("Kanit Medium", size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 20)
            
            accessory
        }
    }
}

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case model = "AI Engine"
    case information = "Information"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "keyboard"
        case .audio: return "mic.fill"
        case .model: return "cpu"
        case .information: return "info.circle.fill"
        }
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    static let preferredWindowSize = CGSize(width: 800, height: 600)
    @Environment(\.dismiss) var dismiss

    @ObservedObject private var downloader = ModelDownloader.shared
    @StateObject private var keyboardMonitor = KeyboardMonitor.shared
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var showLegal = false

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
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            AnimatedWaveHeader()
                .padding(.top, 35)
                .padding(.bottom, 24)
            
            // Navigation Items
            ForEach(SettingsTab.allCases) { tab in
                SidebarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
            
            Spacer()
            
            // Version Info
            Text("Version \(appVersion)")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 32)
        .padding(.top, -8)
        .padding(.bottom, 24)
        .frame(width: 260)
        .background(Color.white.opacity(0.02))
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
    
    // MARK: - Settings Sections
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            Text("KEYBOARD")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                SettingsRow(
                    icon: "keyboard",
                    title: "Trigger Key",
                    subtitle: "Hold this key to start recording. Release to transcribe."
                ) {
                    Picker("", selection: $keyboardMonitor.triggerBinding) {
                        ForEach(KeyboardMonitor.TriggerBinding.allCases) { binding in
                            Text(binding.displayName).tag(binding)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    .labelsHidden()
                }
            }
            
            // Tips as part of General or Info
            tipsSection
        }
    }
    
    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            Text("CUSTOMIZE")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.indigo.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mic.fill")
                            .font(.custom("Kanit Medium", size: 20))
                            .foregroundColor(.indigo)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Microphone Input")
                            .font(.custom("Kanit Medium", size: 17))
                        
                        Text(microphoneSubtitle)
                            .font(.custom("Kanit Medium", size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Picker("", selection: $audioDeviceManager.selectedMicrophoneUID) {
                            ForEach(audioDeviceManager.pickerMicrophones) { microphone in
                                Text(microphonePickerLabel(for: microphone))
                                    .tag(microphone.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .disabled(audioDeviceManager.pickerMicrophones.isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            SettingsCard {
                SettingsRow(
                    icon: "speaker.wave.2.fill",
                    title: "System Sounds",
                    subtitle: "Play audio feedback when recording starts and ends."
                ) {
                    Toggle("", isOn: $keyboardMonitor.isSoundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .indigo))
                        .labelsHidden()
                }
            }
        }
    }
    
    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            Text("MODEL")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                VStack(spacing: 16) {
                    SettingsRow(
                        icon: "cpu",
                        title: "OpenAI Whisper Base",
                        subtitle: "Locally powered high-accuracy English model."
                    ) {
                        if downloader.isModelDownloaded {
                            StatusBadge(title: "Ready", color: .green)
                        } else if downloader.isDownloading {
                            StatusBadge(title: "Installing", color: .yellow)
                        } else {
                            Button("Install") {
                                downloader.downloadBaseModel()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .controlSize(.small)
                        }
                    }
                    
                    if downloader.isDownloading {
                        ModelDownloadProgress(progress: downloader.progress)
                            .padding(.leading, 60)
                    }
                    
                    if let error = downloader.errorMessage {
                        Text(error)
                            .font(.custom("Kanit Medium", size: 10))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var informationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            // About Section
            VStack(alignment: .leading, spacing: 10) {
                Text("ABOUT")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)
                
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("KeyVox is a local first dictation tool that uses OpenAI's Whisper model to transcribe your voice into any application at the speed of thought.")
                            .font(.custom("Kanit Medium", size: 14))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, 12)
            
            // More from Developer Section
            VStack(alignment: .leading, spacing: 10) {
                Text("MORE FROM DEVELOPER")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)
                
                SettingsCard {
                    HStack(spacing: 16) {
                        Image("cueboard-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cueboard")
                                .font(.custom("Kanit Medium", size: 16))
                            Text("Cueboard is a shot list planning tool for creators who think visually. Compatible with iPhone, iPad, and Apple Silicon Mac.")
                                .font(.custom("Kanit Medium", size: 11))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "https://cueboard.app?utm_source=keyvox") {
                                NSWorkspace.shared.open(url)
                                dismiss()
                            }
                        }) {
                            Text("View")
                                .font(.custom("Kanit Medium", size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.indigo.opacity(0.2))
                                .foregroundColor(.indigo)
                                .cornerRadius(8)
                        }
                        .buttonStyle(DepressedButtonStyle())
                    }
                }
            }
            
            HStack {
                Button(action: { showLegal = true }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        Text("Legal & Licenses")
                    }
                    .font(.custom("Kanit Medium", size: 13))
                    .foregroundColor(.indigo)
                }
                .buttonStyle(DepressedButtonStyle())
                .padding(.leading, 8)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(spacing: 12) {
                TipItem(icon: "shift", text: "Shift + Release for Hands-Free")
                TipItem(icon: "escape", text: "Esc to Cancel")
            }
        }
    }

    private var microphoneSubtitle: String {
        guard let selected = audioDeviceManager.selectedMicrophone else {
            if !audioDeviceManager.selectedMicrophoneUID.isEmpty {
                return "Selected mic is unavailable. Built-in Microphone will be used until it reconnects."
            }
            return "Built-in Microphone is recommended for the fastest and most reliable dictation."
        }

        switch selected.kind {
        case .builtIn:
            return "Built-in Microphone selected. Recommended for fastest startup and best reliability."
        case .airPods:
            return "AirPods selected. Bluetooth mics may start slower and reduce dictation accuracy."
        case .bluetooth:
            return "Bluetooth microphone selected. Startup can be slower before dictation begins."
        case .wiredOrOther:
            return "External microphone selected. Built-in Microphone is still recommended for best speed."
        }
    }

    private func microphonePickerLabel(for microphone: MicrophoneOption) -> String {
        if !microphone.isAvailable {
            return "Previously Selected Microphone (Unavailable)"
        }

        if microphone.kind == .builtIn {
            return "\(microphone.name) (Recommended)"
        }

        return microphone.name
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Sidebar Supporting View
struct SidebarItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                Text(tab.rawValue)
                    .font(.custom("Kanit Medium", size: 15))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.indigo.opacity(0.3) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(DepressedButtonStyle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Custom Button Styles
struct DepressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title.uppercased())
            .font(.custom("Kanit Medium", size: 9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

struct TipItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.yellow)
            Text(text)
                .font(.custom("Kanit Medium", size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    SettingsView()
}
