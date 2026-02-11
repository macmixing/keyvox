import SwiftUI

// MARK: - Animated Wave Header with Circle
struct AnimatedWaveHeader: View {
    @State private var ripplePhase: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Circle with animated bars (like RecordingOverlay)
            ZStack {
                Circle()
                    .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                HStack(spacing: 3) {
                    ForEach(0..<5) { index in
                        MiniBarView(index: index, ripplePhase: ripplePhase)
                    }
                }
            }
            
            Text("KeyVox Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.indigo)
        }
        .onAppear {
            startRippleAnimation()
        }
    }
    
    private func startRippleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            ripplePhase += 0.1
            if ripplePhase > .pi * 2 {
                ripplePhase = 0
            }
        }
    }
}

struct MiniBarView: View {
    let index: Int
    let ripplePhase: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [Color.indigo, Color.indigo.opacity(0.9)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.6), radius: 2, x: 0, y: 0)
            .frame(width: 3, height: height)
            .animation(.linear(duration: 0.1), value: ripplePhase)
    }
    
    var height: CGFloat {
        let waveOffset = ripplePhase + Double(index) * 0.8
        let rippleHeight = sin(waveOffset) * 0.5 + 0.5
        return 6 + (CGFloat(rippleHeight) * 8)
    }
}

// MARK: - Settings Section with Hover Effect
struct SettingsSection<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color.white.opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.yellow.opacity(isHovered ? 0.6 : 0.2), lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    @StateObject private var downloader = ModelDownloader()
    @StateObject private var keyboardMonitor = KeyboardMonitor.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                AnimatedWaveHeader()


                Divider()

                // MARK: - Push-to-talk Key

                SettingsSection {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("KeyVox Trigger")
                            .font(.subheadline)
                            .fontWeight(.bold)

                        Text("Choose which key you hold to start dictation.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Trigger Key", selection: $keyboardMonitor.triggerBinding) {
                            ForEach(KeyboardMonitor.TriggerBinding.allCases, id: \.self) { binding in
                                Text(binding.displayName).tag(binding)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Text("Current: \(keyboardMonitor.triggerBinding.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Model Download

                SettingsSection {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Whisper Model")
                            .font(.subheadline)
                            .fontWeight(.bold)

                        if downloader.isModelDownloaded {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Model is ready.")
                            }
                        } else {
                            Text("The AI model is required for transcription.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if downloader.isDownloading {
                                ProgressView(value: downloader.progress) {
                                    Text("Downloading: \(Int(downloader.progress * 100))%")
                                        .font(.caption)
                                }
                            } else {
                                Button("Download Model") {
                                    downloader.downloadBaseModel()
                                }
                            }

                            if let error = downloader.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }

            }
            .padding([.horizontal, .bottom])
            .padding(.top, -10)
        }
        .frame(width: 400, height: 350)
    }
}

#Preview {
    SettingsView()
}
