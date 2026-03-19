import SwiftUI
import KeyVoxCore

struct DictionaryTabView: View {
    let isActive: Bool

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @State private var dictionarySortMode: DictionarySortMode = .alphabetical
    @State private var dictionaryEditorMode: DictionaryWordEditorMode?
    @State private var isFloatingAddButtonVisible = false
    @State private var lastPresentedEditorID: String?
    @State private var shouldEmitSortSelectionHaptic = true

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
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            List {
                if let warning = dictionaryStore.loadWarningMessage {
                    statusMessageRow(warning)
                }

                if let saveError = dictionaryStore.saveErrorMessage {
                    statusMessageRow(saveError)
                }

                Picker("Sort Dictionary Entries", selection: $dictionarySortMode) {
                    ForEach(DictionarySortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 10)
                .dictionaryScreenRow(top: 12, bottom: displayedEntries.isEmpty ? 10 : 14)

                if displayedEntries.isEmpty {
                    ContentUnavailableView(
                        "No custom words added yet.",
                        systemImage: "text.book.closed",
                        description: Text("Tap the plus button to add your first custom word.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
                    .dictionaryScreenRow(top: 0, bottom: 0)
                } else {
                    ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { index, entry in
                        DictionaryEntryRowView(
                            entry: entry,
                            onEdit: { dictionaryEditorMode = .edit(entry) },
                            onDelete: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dictionaryStore.delete(id: entry.id)
                                }
                            }
                        )
                        .dictionaryEntryListRow(bottom: index == displayedEntries.indices.last ? 4 : 13)
                    }
                }

                Text("Custom dictionary correction is currently supported for English only.")
                    .font(.appFont(11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .dictionaryScreenRow(top: 4, bottom: 0)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .contentMargins(.top, AppScrollScreen<EmptyView>.sharedTopContentInset, for: .scrollContent)
            .animation(.easeInOut(duration: 0.3), value: displayedEntries.map(\.id))
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
                        shouldEmitSortSelectionHaptic = false
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
        .onChange(of: dictionarySortMode, initial: false) { _, _ in
            guard shouldEmitSortSelectionHaptic else {
                shouldEmitSortSelectionHaptic = true
                return
            }
            appHaptics.selection()
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
        appHaptics.light()
        dictionaryEditorMode = .add
    }

    private var animationTriggerID: String {
        "\(isActive)-\(dictionaryEditorMode?.id ?? "none")"
    }

    private func statusMessageRow(_ message: String) -> some View {
        Text(message)
            .font(.appFont(12))
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .dictionaryScreenRow(top: 0, bottom: 10)
    }
}

private extension View {
    func dictionaryScreenRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(
            EdgeInsets(
                top: top,
                leading: AppTheme.screenPadding,
                bottom: bottom,
                trailing: AppTheme.screenPadding
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    func dictionaryEntryListRow(bottom: CGFloat) -> some View {
        listRowInsets(
            EdgeInsets(
                top: 0,
                leading: AppTheme.screenPadding,
                bottom: bottom,
                trailing: AppTheme.screenPadding
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    DictionaryTabView(isActive: true)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
}
