import SwiftUI

struct SettingsView: View {
    @StateObject private var downloader = ModelDownloader()
    @StateObject private var keyboardMonitor = KeyboardMonitor.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("KeyVox Settings")
                .font(.headline)

            Divider()

            // MARK: - Push-to-talk Key

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
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // MARK: - Model Download

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
                        Button("Download Model (142MB)") {
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
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Spacer()

            Button("Close") {
                NSApp.keyWindow?.close()
            }
        }
        .padding()
        .frame(width: 350, height: 390)
    }
}

#Preview {
    SettingsView()
}
