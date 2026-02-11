import SwiftUI
import AVFoundation
import ApplicationServices

struct StatusMenuView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: TranscriptionManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @ObservedObject var downloader = ModelDownloader.shared
    @State private var micAuthorized: Bool = (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized)
    
    var openSettings: () -> Void
    var quitApp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                // Header / Status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KeyVox Status")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(currentStatus.text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    StatusIndicator(status: currentStatus)
                }
                
                Divider()
                    .opacity(0.1)
                
                // Warnings Section (Only show after onboarding is complete)
                if hasCompletedOnboarding && (!micAuthorized || !downloader.isModelDownloaded || !AXIsProcessTrusted()) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !micAuthorized {
                            WarningRow(icon: "mic.slash", title: "No Mic Permissions") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        
                        if !downloader.isModelDownloaded {
                            WarningRow(icon: "cpu", title: "Model missing") {
                                dismiss()
                                openSettings()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    ModelDownloader.shared.downloadBaseModel()
                                }
                            }
                        }
                        
                        if !AXIsProcessTrusted() {
                            WarningRow(icon: "accessibility", title: "Accessibility Required") {
                                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                                AXIsProcessTrustedWithOptions(options as CFDictionary)
                            }
                        }
                    }
                    
                    Divider()
                        .opacity(0.1)
                }
                
                // Actions
                VStack(spacing: 2) {
                    MenuActionRow(
                        icon: "gearshape.fill",
                        title: "Settings",
                        disabled: !hasCompletedOnboarding
                    ) {
                        dismiss()
                        openSettings()
                    }
                    
                    MenuActionRow(icon: "power", title: "Quit KeyVox") {
                        dismiss()
                        quitApp()
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.05)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: micAuthorized)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: downloader.isModelDownloaded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: AXIsProcessTrusted())
        .onAppear {
            downloader.refreshModelStatus()
        }
    }
    
    enum AppStatus {
        case onboarding
        case issue
        case idle
        case recording
        case transcribing
        case error(String)
        
        var text: String {
            switch self {
            case .onboarding: return "Waiting"
            case .issue: return "Issue!"
            case .idle: return "Ready"
            case .recording: return "Recording..."
            case .transcribing: return "Processing..."
            case .error(let msg): return "Error: \(msg)"
            }
        }
        
        var color: Color {
            switch self {
            case .onboarding: return .yellow
            case .issue: return .red
            case .idle: return .green
            case .recording: return .red
            case .transcribing: return .blue
            case .error: return .orange
            }
        }
    }
    
    private var currentStatus: AppStatus {
        if !hasCompletedOnboarding {
            return .onboarding
        }
        
        // After onboarding, check for blocking issues
        if !micAuthorized || !downloader.isModelDownloaded || !AXIsProcessTrusted() {
            return .issue
        }
        
        switch manager.state {
        case .idle: return .idle
        case .recording: return .recording
        case .transcribing: return .transcribing
        case .error(let msg): return .error(msg)
        }
    }
    
    private func checkMicPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        micAuthorized = (status == .authorized)
    }
    
    private func requestMicAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            DispatchQueue.main.async {
                self.checkMicPermissions()
            }
        }
    }
}

// MARK: - Supporting Views

struct StatusIndicator: View {
    let status: StatusMenuView.AppStatus
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .shadow(color: status.color.opacity(0.5), radius: 3)
    }
}

struct WarningRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.red : Color.red.opacity(0.1))
                
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isHovering ? .white : .red)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(isHovering ? "Click to resolve" : title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isHovering ? .white : .red.opacity(0.9))
                        
                        // Keep title visible on hover so they know what they are clicking
                        if isHovering {
                            Text(title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct MenuActionRow: View {
    let icon: String
    let title: String
    var disabled: Bool = false
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovering && !disabled ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1.0)
        .onHover { isHovering = $0 }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


