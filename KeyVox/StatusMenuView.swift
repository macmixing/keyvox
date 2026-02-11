import SwiftUI
import AVFoundation

struct StatusMenuView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: TranscriptionManager
    @ObservedObject var downloader = ModelDownloader.shared
    @State private var micAuthorized: Bool = true
    
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
                        Text(statusText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    StatusIndicator(state: manager.state)
                }
                
                Divider()
                    .opacity(0.1)
                
                // Warnings Section
                if !micAuthorized || !downloader.isModelDownloaded || !AXIsProcessTrusted() {
                    VStack(alignment: .leading, spacing: 4) {
                        if !micAuthorized {
                            WarningRow(icon: "mic.slash", title: "No Mic Permissions") {
                                requestMicAccess()
                            }
                        }
                        
                        if !downloader.isModelDownloaded {
                            WarningRow(icon: "cpu", title: "Model missing") {
                                dismiss()
                                openSettings()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    downloader.downloadBaseModel()
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
                    MenuActionRow(icon: "gearshape.fill", title: "Settings") {
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
            checkMicPermissions()
        }
    }
    
    private var statusText: String {
        switch manager.state {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Processing..."
        case .error(let msg): return "Error: \(msg)"
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
    let state: TranscriptionManager.AppState
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.5), radius: 3)
    }
    
    private var color: Color {
        switch state {
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .blue
        case .error: return .orange
        }
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
            .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
