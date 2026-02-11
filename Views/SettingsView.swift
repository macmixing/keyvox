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
                Text("flow at the speed of thought")
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
            .padding(.horizontal)
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

// MARK: - Main Settings View
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var downloader = ModelDownloader.shared
    @StateObject private var keyboardMonitor = KeyboardMonitor.shared
    @State private var showLegal = false

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                // Header
                headerView
                    .offset(y: -15)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Section: Trigger Key
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
                                .frame(width: 140)
                                .labelsHidden()
                            }
                        }
                        
                        // Section: Whisper Model
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
                        
                        // Section: Tips
                        tipsSection
                        
                        Divider()
                            .opacity(0.1)
                            .padding(.horizontal, 24)
                        
                        Button("Legal & Licenses") {
                            showLegal = true
                        }
                        .font(.custom("Kanit Medium", size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                        .buttonStyle(.plain)
                        .padding(.bottom, 16)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.top, 32)
        }
        .frame(width: 500, height: 480)
        .background(
            Color.indigo.opacity(0.15)
                .background(Color(white: 0.01))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .sheet(isPresented: $showLegal) {
            LegalView()
        }
    }
    
    private var headerView: some View {
        HStack {
            AnimatedWaveHeader()
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .offset(y: -5)
        }
        .padding(.horizontal, 24)
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK TIPS")
                .font(.custom("Kanit Medium", size: 11))
                .foregroundColor(.secondary)
                .tracking(1)
                .padding(.leading, 8)
            
            HStack(spacing: 12) {
                TipItem(icon: "shift", text: "Shift + Release for Hands-Free")
                TipItem(icon: "escape", text: "Esc to Cancel")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
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

