import SwiftUI

extension SettingsView {
    var styleSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 4)

            SettingsCard {
                SettingsRow(
                    icon: "list.bullet",
                    title: "Lists",
                    subtitle: "Format spoken numbered lists automatically when detected."
                ) {
                    Toggle("", isOn: $appSettings.listFormattingEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
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
                }
            }
        }
    }
}
