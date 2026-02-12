import SwiftUI

extension SettingsView {
    var modelSettings: some View {
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
}
