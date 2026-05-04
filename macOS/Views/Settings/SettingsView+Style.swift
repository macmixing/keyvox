import SwiftUI
import KeyVoxStyleRewrite

extension SettingsView {
    var styleSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 4)

            if appSettings.canUseVibes {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsRow(
                            assetIcon: "vibes-logo",
                            title: "KeyVox Vibes",
                            subtitle: "On-device, reversible writing styles."
                        ) {
                            Picker("", selection: $appSettings.selectedVibe) {
                                ForEach(StyleRewriteStyle.allCases) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .accessibilityLabel("KeyVox Vibes")
                        }

                        Divider()
                            .background(Color.white.opacity(0.22))

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(StyleRewriteStyle.allCases) { style in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(style.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)

                                    Text(style.exampleText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(MacAppTheme.accent)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }

                HStack {
                    Spacer()
                    TipItem(
                        icon: "keyboard",
                        text: "Tap the trigger key to apply / undo the current Vibe. Double-tap to cycle Vibes."
                    )
                    Spacer()
                }
            }

            SettingsCard {
                SettingsRow(
                    icon: "list.bullet",
                    title: "Lists",
                    subtitle: "Format spoken numbered lists automatically when detected."
                ) {
                    Toggle("", isOn: $appSettings.listFormattingEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("Lists")
                }
            }

            SettingsCard {
                SettingsRow(
                    icon: "text.alignleft",
                    title: "Paragraphs",
                    subtitle: "Start new paragraphs automatically after brief pauses in multiline fields."
                ) {
                    Toggle("", isOn: $appSettings.autoParagraphsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("Paragraphs")
                }
            }
        }
    }
}
