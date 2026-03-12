import SwiftUI

extension SettingsView {
    var moreSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM")
                    .font(.appFont(10))
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
                                .font(.appFont(11))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if loginItemController.shouldShowOpenSystemSettingsAction {
                            Button("Open Login Items Settings") {
                                loginItemController.openLoginItemsSettings()
                            }
                            .font(.appFont(12))
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
                    .font(.appFont(10))
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
                                    .font(.appFont(16))
                                Text("Cueboard is a shot list planning tool for creators who think visually. Compatible with iPhone, iPad, and Apple Silicon Mac.")
                                    .font(.appFont(11))
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
                                    .font(.appFont(12))
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
                    .font(.appFont(13))
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
                .font(.appFont(12))
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
