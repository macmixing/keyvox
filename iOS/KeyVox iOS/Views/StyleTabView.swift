import SwiftUI

struct StyleTabView: View {
    @EnvironmentObject private var settingsStore: iOSAppSettingsStore

    var body: some View {
        iOSAppScrollScreen {
            iOSAppCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Style")
                        .font(.appFont(17))
                        .foregroundStyle(.white)

                    Toggle(isOn: $settingsStore.autoParagraphsEnabled) {
                        Text("Auto paragraphs")
                            .font(.appFont(16))
                            .foregroundStyle(.white)
                    }

                    Toggle(isOn: $settingsStore.listFormattingEnabled) {
                        Text("List formatting")
                            .font(.appFont(16))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    StyleTabView()
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
}
