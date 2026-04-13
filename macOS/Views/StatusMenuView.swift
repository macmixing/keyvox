import SwiftUI
import AVFoundation
import ApplicationServices

struct StatusMenuView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: TranscriptionManager
    @ObservedObject private var appSettings = AppSettingsStore.shared
    @ObservedObject var downloader = ModelDownloader.shared
    @State private var micAuthorized: Bool = (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized)
    
    var openSettings: (SettingsTab) -> Void
    var checkForUpdates: () -> Void
    var quitApp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                // Header / Status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KeyVox Status")
                            .font(.appFont(12, variant: .medium))
                            .foregroundColor(.secondary)
                        HStack(alignment: .center, spacing: 6) {
                            Text(currentStatus.text)
                                .font(.appFont(12, variant: .medium))
                                .foregroundColor(.primary)
                            StatusIndicator(status: currentStatus)
                                .offset(y: 1)
                        }
                    }
                    Spacer()
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 0.5)
                
                // Warnings Section (Only show after onboarding is complete)
                if appSettings.hasCompletedOnboarding && (!micAuthorized || !activeProviderModelReady || !AXIsProcessTrusted()) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !micAuthorized {
                            WarningRow(icon: "mic.slash", title: "No Mic Permissions") {
                                resolveMicrophonePermission()
                            }
                        }
                        
                        if !activeProviderModelReady {
                            WarningRow(icon: "cpu", title: "Model missing") {
                                dismiss()
                                openSettings(.settings)
                                DispatchQueue.main.async {
                                    ModelDownloader.shared.downloadModel(withID: appSettings.activeDictationProvider.modelID)
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
                    
                }
                
                // Actions
                VStack(spacing: 2) {
                    MenuActionRow(
                        icon: "gearshape.fill",
                        title: "Settings",
                        disabled: !appSettings.hasCompletedOnboarding
                    ) {
                        dismiss()
                        openSettings(.home)
                    }

                    MenuActionRow(icon: "arrow.triangle.2.circlepath", title: "Check for Updates") {
                        dismiss()
                        checkForUpdates()
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeProviderModelReady)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: AXIsProcessTrusted())
        .onAppear {
            micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
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
        if !appSettings.hasCompletedOnboarding {
            return .onboarding
        }
        
        // After onboarding, check for blocking issues
        if !micAuthorized || !activeProviderModelReady || !AXIsProcessTrusted() {
            return .issue
        }
        
        switch manager.state {
        case .idle: return .idle
        case .recording: return .recording
        case .stopping: return .transcribing
        case .transcribing: return .transcribing
        case .error(let msg): return .error(msg)
        }
    }

    private var activeProviderModelReady: Bool {
        downloader.isModelReady(for: appSettings.activeDictationProvider.modelID)
    }

    private func resolveMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            micAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.micAuthorized = granted
                    if !granted {
                        self.openMicrophonePrivacySettings()
                    }
                }
            }
        case .denied, .restricted:
            openMicrophonePrivacySettings()
        @unknown default:
            openMicrophonePrivacySettings()
        }
    }

    private func openMicrophonePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
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
                        .font(.appFont(12, variant: .medium))
                        .foregroundColor(isHovering ? .white : .red)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(isHovering ? "Click to resolve" : title)
                            .font(.appFont(12, variant: .medium))
                            .foregroundColor(isHovering ? .white : .red.opacity(0.9))
                        
                        // Keep title visible on hover so they know what they are clicking
                        if isHovering {
                            Text(title)
                                .font(.appFont(12, variant: .light))
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
                    .font(.appFont(12, variant: .light))
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
