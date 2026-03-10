import SwiftUI

struct StyleTabView: View {
    @EnvironmentObject private var settingsStore: iOSAppSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Style")
                    .font(.headline)

                Toggle("Auto paragraphs", isOn: $settingsStore.autoParagraphsEnabled)
                Toggle("List formatting", isOn: $settingsStore.listFormattingEnabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    StyleTabView()
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
}
