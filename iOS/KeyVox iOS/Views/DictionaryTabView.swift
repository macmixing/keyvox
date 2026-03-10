import SwiftUI
import KeyVoxCore

struct DictionaryTabView: View {
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dictionary")
                    .font(.headline)

                if dictionaryStore.entries.isEmpty {
                    Text("No dictionary entries yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(dictionaryStore.entries) { entry in
                            Text(entry.phrase)
                                .font(.footnote.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    DictionaryTabView()
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
