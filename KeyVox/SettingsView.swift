import SwiftUI

struct SettingsView: View {
    @StateObject private var downloader = ModelDownloader()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Divider()
            
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
        .frame(width: 350, height: 250)
    }
}

#Preview {
    SettingsView()
}
