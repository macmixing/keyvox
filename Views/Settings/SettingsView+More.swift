import SwiftUI

extension SettingsView {
    var moreSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                SettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsRow(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "Launch at Login",
                            subtitle: loginItemController.subtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { loginItemController.isEnabled },
                                    set: { loginItemController.setEnabled($0) }
                                )
                            )
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(loginItemController.isUpdating)
                        }

                        if let errorMessage = loginItemController.errorMessage {
                            Text(errorMessage)
                                .font(.custom("Kanit Medium", size: 11))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if loginItemController.shouldShowOpenSystemSettingsAction {
                            Button("Open Login Items Settings") {
                                loginItemController.openLoginItemsSettings()
                            }
                            .font(.custom("Kanit Medium", size: 12))
                            .foregroundColor(.indigo)
                            .buttonStyle(DepressedButtonStyle())
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.14))
                            .padding(.vertical, 2)

                        ModelSettingsRow(downloader: downloader)
                    }
                }
            }
            
            // More from Developer Section
            VStack(alignment: .leading, spacing: 10) {
                Text("MORE FROM DEVELOPER")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)
                
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 16) {
                            Image("cueboard-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cueboard")
                                    .font(.custom("Kanit Medium", size: 16))
                                Text("Cueboard is a shot list planning tool for creators who think visually. Compatible with iPhone, iPad, and Apple Silicon Mac.")
                                    .font(.custom("Kanit Medium", size: 11))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                            }

                            Spacer()

                            Button(action: {
                                if let url = URL(string: "https://cueboard.app?utm_source=keyvox-app-settings") {
                                    NSWorkspace.shared.open(url)
                                    dismiss()
                                }
                            }) {
                                Text("View")
                                    .font(.custom("Kanit Medium", size: 12))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.indigo.opacity(0.2))
                                    .foregroundColor(.indigo)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(DepressedButtonStyle())
                        }
                    }
                }
            }
            
            HStack {
                Button(action: { showLegal = true }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        Text("Legal & Licenses")
                    }
                    .font(.custom("Kanit Medium", size: 13))
                    .foregroundColor(.indigo)
                }
                .buttonStyle(DepressedButtonStyle())
                .padding(.leading, 8)

                Spacer()

                GitHubSupportLink(onOpen: {
                    dismiss()
                })
                .padding(.trailing, 8)
            }
            .padding(.top, 8)
        }
        .onAppear {
            loginItemController.refreshStatus()
        }
    }
}

private struct ModelSettingsRow: View {
    @ObservedObject var downloader: ModelDownloader
    @State private var isReadyHovered = false
    private let actionPillWidth: CGFloat = 84

    var body: some View {
        VStack(spacing: 16) {
            SettingsRow(
                icon: "cpu",
                title: "OpenAI Whisper Base",
                subtitle: "Locally powered high-accuracy English model."
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var readyBadgeLabel: some View {
        Text("READY")
            .font(.custom("Kanit Medium", size: 9))
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

private struct GitHubSupportLink: View {
    private let supportURL = URL(string: "https://github.com/sponsors/macmixing")!
    let onOpen: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(supportURL)
            onOpen()
        }) {
            Text("Support KeyVox on GitHub")
                .font(.custom("Kanit Medium", size: 12))
                .foregroundColor(isHovered ? .yellow : .white)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
