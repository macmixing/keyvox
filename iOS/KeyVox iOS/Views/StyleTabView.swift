import SwiftUI

struct StyleTabView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                AppCard {
                    SettingsRow(
                        icon: "list.number",
                        title: "Lists",
                        description: "Format spoken numbered lists automatically when detected.",
                        isOn: $settingsStore.listFormattingEnabled
                    )
                }
                
                AppCard {
                    SettingsRow(
                        icon: "text.alignleft",
                        title: "Paragraphs",
                        description: "Start new paragraphs automatically after brief pauses in multiline fields.",
                        isOn: $settingsStore.autoParagraphsEnabled
                    )
                }
            }
        }
    }
}

#Preview {
    StyleTabView()
        .environmentObject(AppServiceRegistry.shared.settingsStore)
}
