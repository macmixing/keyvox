import SwiftUI
import KeyVoxCore

struct DictionaryTabView: View {
    let isActive: Bool

    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @State private var dictionarySortMode: DictionarySortMode = .alphabetical
    @State private var dictionaryEditorMode: DictionaryWordEditorMode?
    @State private var isFloatingAddButtonVisible = false
    @State private var lastPresentedEditorID: String?

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

    private var showsFloatingAddButton: Bool {
        dictionaryEditorMode == nil
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
            if showsFloatingAddButton {
                DictionaryFloatingAddButton(action: presentAddWordEditor)
                    .scaleEffect(isFloatingAddButtonVisible ? 1 : 0.82)
                    .opacity(isFloatingAddButtonVisible ? 1 : 0)
                    .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isFloatingAddButtonVisible)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
        }
        .sheet(item: $dictionaryEditorMode) { mode in
            DictionaryWordEditorView(
                mode: mode,
                onSave: {
                    if case .add = mode, dictionarySortMode != .recentlyAdded {
                        dictionarySortMode = .recentlyAdded
                    }
                }
            )
        }
        .onChange(of: dictionaryEditorMode?.id) { _, newValue in
            if let newValue {
                lastPresentedEditorID = newValue
            }
        }
        .task(id: animationTriggerID) {
            guard isActive, dictionaryEditorMode == nil else {
                isFloatingAddButtonVisible = false
                return
            }

            isFloatingAddButtonVisible = false

            if lastPresentedEditorID != nil {
                try? await Task.sleep(for: .seconds(0.2))
                lastPresentedEditorID = nil
            } else {
                try? await Task.sleep(for: .seconds(0.1))
            }

            await Task.yield()

            withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                isFloatingAddButtonVisible = true
            }
        }
        .onDisappear {
            isFloatingAddButtonVisible = false
            lastPresentedEditorID = nil
            dictionaryStore.clearWarnings()
        }
    }

    private func presentAddWordEditor() {
        dictionaryEditorMode = .add
    }

    private var animationTriggerID: String {
        "\(isActive)-\(dictionaryEditorMode?.id ?? "none")"
    }
}

#Preview {
    DictionaryTabView(isActive: true)
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
