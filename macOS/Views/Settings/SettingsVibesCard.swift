import SwiftUI
import KeyVoxStyleRewrite

struct SettingsVibesCard: View {
    @Binding var selectedVibe: StyleRewriteStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsRow(
                        assetIcon: "vibes-logo",
                        title: "KeyVox Vibes",
                        subtitle: "On-device, reversible writing styles."
                    ) {
                        Picker("", selection: $selectedVibe) {
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
    }
}
