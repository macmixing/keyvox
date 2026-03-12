import SwiftUI
import KeyVoxCore

struct DictionaryTabView: View {
    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @State private var dictionarySortMode: DictionarySortMode = .alphabetical
    @State private var dictionaryEditorMode: DictionaryWordEditorMode?

    private var displayedEntries: [DictionaryEntry] {
        switch dictionarySortMode {
        case .alphabetical:
            return dictionaryStore.entries.sorted {
                let order = $0.phrase.localizedCaseInsensitiveCompare($1.phrase)
                if order == .orderedSame {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return order == .orderedAscending
            }
        case .recentlyAdded:
            return Array(dictionaryStore.entries.reversed())
        }
    }

    var body: some View {
        iOSAppScrollScreen {
            VStack(alignment: .leading, spacing: 10) {
                if let warning = dictionaryStore.loadWarningMessage {
                    Text(warning)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let saveError = dictionaryStore.saveErrorMessage {
                    Text(saveError)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                iOSAppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Sort Dictionary Entries", selection: $dictionarySortMode) {
                            ForEach(DictionarySortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 20)

                        if displayedEntries.isEmpty {
                            ContentUnavailableView(
                                "No custom words added yet.",
                                systemImage: "text.book.closed",
                                description: Text("Tap the plus button to add your first custom word.")
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(displayedEntries) { entry in
                                    DictionaryEntryRowView(
                                        entry: entry,
                                        onEdit: { dictionaryEditorMode = .edit(entry) },
                                        onDelete: { dictionaryStore.delete(id: entry.id) }
                                    )
                                }
                            }
                        }
                    }
                }

                Text("Custom dictionary correction is currently supported for English only.")
                    .font(.appFont(11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if dictionaryEditorMode == nil {
                DictionaryFloatingAddButton(action: presentAddWordEditor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
        }
        .sheet(item: $dictionaryEditorMode) { mode in
            DictionaryWordEditorView(mode: mode)
        }
        .onDisappear {
            dictionaryStore.clearWarnings()
        }
    }

    private func presentAddWordEditor() {
        dictionaryEditorMode = .add
    }
}

#Preview {
    DictionaryTabView()
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
