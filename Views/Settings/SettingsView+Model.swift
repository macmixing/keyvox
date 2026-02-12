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
                ModelSettingsRow(downloader: downloader)
            }
        }
    }
}

private struct ModelSettingsRow: View {
    @ObservedObject var downloader: ModelDownloader
    @State private var isReadyHovered = false
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsRow(
                icon: "cpu",
                title: "OpenAI Whisper Base",
                subtitle: "Locally powered high-accuracy English model."
            ) {
                // Accessory Area
                ZStack(alignment: .trailing) {
                    if downloader.isModelDownloaded {
                        // The REMOVE button defines the maximum width of the ZStack
                        Button(action: { downloader.deleteModel() }) {
                            removeButtonLabel
                        }
                        .buttonStyle(.plain)
                        .opacity(isReadyHovered ? 1.0 : 0.0)
                        .allowsHitTesting(isReadyHovered)
                        
                        // The READY badge sits behind it if not hovered
                        StatusBadge(title: "Ready", color: .green)
                            .opacity(isReadyHovered ? 0.0 : 1.0)
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
                .onHover { isReadyHovered = $0 }
                .animation(.none, value: isReadyHovered)
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

    private var removeButtonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "xmark.circle.fill")
            Text("REMOVE")
        }
        .font(.custom("Kanit Medium", size: 9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
