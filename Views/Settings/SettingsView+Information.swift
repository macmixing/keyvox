import SwiftUI

extension SettingsView {
    var informationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            // About Section
            VStack(alignment: .leading, spacing: 10) {
                Text("ABOUT")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)
                
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("KeyVox is a local first dictation tool that uses OpenAI's Whisper model to transcribe your voice into any application at the speed of thought.")
                            .font(.custom("Kanit Medium", size: 14))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                                if let url = URL(string: "https://cueboard.app?utm_source=keyvox") {
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
