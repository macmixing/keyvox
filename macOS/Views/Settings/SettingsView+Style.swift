import Foundation
import SwiftUI

extension SettingsView {
    var styleSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 4)

            SettingsVibesCard(
                selectedVibe: $appSettings.selectedVibe,
                dictationModel: appSettings.activeDictationProvider.styleRewriteDictationModel,
                installState: localRewriteModelManager.installState,
                downloadAction: {
                    localRewriteModelManager.downloadModel()
                },
                repairAction: {
                    localRewriteModelManager.downloadModel()
                }
            )

            SettingsCard {
                SettingsRow(
                    icon: "list.bullet",
                    title: String(localized: "Lists", comment: "Title of the Settings row and VoiceOver label of its toggle for automatic numbered list formatting."),
                    subtitle: String(localized: "Format spoken numbered lists automatically when detected.", comment: "Subtitle of the Lists row in Settings.")
                ) {
                    Toggle("", isOn: $appSettings.listFormattingEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(String(localized: "Lists", comment: "Title of the Settings row and VoiceOver label of its toggle for automatic numbered list formatting."))
                }
            }

            SettingsCard {
                SettingsRow(
                    icon: "text.alignleft",
                    title: String(localized: "Paragraphs", comment: "Title of the Settings row and VoiceOver label of its toggle for automatic paragraph breaks."),
                    subtitle: String(localized: "Start new paragraphs automatically after brief pauses in multiline fields.", comment: "Subtitle of the Paragraphs row in Settings.")
                ) {
                    Toggle("", isOn: $appSettings.autoParagraphsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(String(localized: "Paragraphs", comment: "Title of the Settings row and VoiceOver label of its toggle for automatic paragraph breaks."))
                }
            }

            HStack {
                Spacer()
                TipItem(
                    icon: "keyboard",
                    text: String(localized: "Hold the trigger key, then press L for Lists or P for Paragraphs. Repeat to undo.", comment: "Tip on the Style page in Settings. L and P are keyboard keys and stay as written. Lists and Paragraphs are the row titles above; translate them the same way as those titles.")
                )
                Spacer()
            }
        }
    }
}
