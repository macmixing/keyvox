import SwiftUI

struct StyleTabView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore

    var body: some View {
        AppScrollScreen {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Style")
                        .font(.appFont(17))
                        .foregroundStyle(.white)

                    Toggle(isOn: $settingsStore.autoParagraphsEnabled) {
                        Text("Auto paragraphs")
                            .font(.appFont(16, variant: .light))
                            .foregroundStyle(.white)
                    }

                    Toggle(isOn: $settingsStore.listFormattingEnabled) {
                        Text("List formatting")
                            .font(.appFont(16, variant: .light))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    StyleTabView()
        .environmentObject(AppServiceRegistry.shared.settingsStore)
}
