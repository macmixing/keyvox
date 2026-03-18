import SwiftUI

struct ModelSettingsRow: View {
    @ObservedObject var downloader: ModelDownloader
    @State private var isReadyHovered = false
    private let actionPillWidth: CGFloat = 84

    var body: some View {
        VStack(spacing: 16) {
            SettingsRow(
                icon: "cpu",
                title: "OpenAI Whisper Base",
                subtitle: "Locally powered multi-lingual model."
            ) {
                ZStack(alignment: .trailing) {
                    if downloader.isModelDownloaded {
                        Button(action: { downloader.deleteModel() }) {
                            removeButtonLabel
                                .frame(width: actionPillWidth)
                        }
                        .buttonStyle(.plain)
                        .opacity(isReadyHovered ? 1.0 : 0.0)
                        .allowsHitTesting(isReadyHovered)

                        readyBadgeLabel
                            .frame(width: actionPillWidth)
                            .opacity(isReadyHovered ? 0.0 : 1.0)
                    } else if downloader.isDownloading {
                        StatusBadge(title: "Installing", color: .yellow)
                    } else {
                        Button("Install") {
                            downloader.downloadBaseModel()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MacAppTheme.accent)
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
                    .font(.appFont(10))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var removeButtonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "xmark.circle.fill")
            Text("REMOVE")
        }
        .font(.appFont(9))
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

    private var readyBadgeLabel: some View {
        Text("READY")
            .font(.appFont(9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
    }
}
