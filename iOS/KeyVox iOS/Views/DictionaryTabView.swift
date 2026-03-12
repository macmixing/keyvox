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
                DictionaryHeaderCardView()

                Button(action: presentAddWordEditor) {
                    Text("Add Word")
                        .font(.appFont(22))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(iOSAppTheme.accent)
                        )
                }
                .buttonStyle(.plain)
                .containerRelativeFrame(.horizontal) { length, _ in
                    length * 0.8
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
                .padding(.bottom, 20)

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
                        if displayedEntries.isEmpty {
                            ContentUnavailableView(
                                "No custom words added yet.",
                                systemImage: "text.book.closed",
                                description: Text("Add words, email addresses, and short phrases to improve transcription accuracy.")
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            Picker("Sort Dictionary Entries", selection: $dictionarySortMode) {
                                ForEach(DictionarySortMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

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
