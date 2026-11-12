import Foundation
import SwiftUI
import KeyVoxCore

enum DictionaryWordEditorMode: Identifiable {
    case add
    case edit(DictionaryEntry)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let entry):
            return "edit-\(entry.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .add:
            return String(localized: "Add Dictionary Word", comment: "Title of the dictionary word editor sheet when adding a word.")
        case .edit:
            return String(localized: "Edit Dictionary Word", comment: "Title of the dictionary word editor sheet when editing a word.")
        }
    }

    var actionTitle: String {
        switch self {
        case .add:
            return String(localized: "Add Word", comment: "Button in the dictionary word editor sheet that adds the word.")
        case .edit:
            return String(localized: "Save Word", comment: "Button in the dictionary word editor sheet that saves the edited word.")
        }
    }

    var initialPhrase: String {
        switch self {
        case .add:
            return ""
        case .edit(let entry):
            return entry.phrase
        }
    }
}

private enum DictionaryWordEditorLayout {
    static let width: CGFloat = 460
    static let height: CGFloat = 200
    static let actionButtonWidth: CGFloat = 126
}

struct DictionaryWordEditorView: View {
    let mode: DictionaryWordEditorMode
    @ObservedObject var dictionaryStore: DictionaryStore
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var phrase: String
    @State private var errorMessage: String?

    init(
        mode: DictionaryWordEditorMode,
        dictionaryStore: DictionaryStore,
        onSave: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.dictionaryStore = dictionaryStore
        self.onSave = onSave
        _phrase = State(initialValue: mode.initialPhrase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode.title)
                    .font(.appFont(19))
                    .foregroundColor(.white)

                Text("Type the exact word or phrase you want KeyVox to preserve.", comment: "Instruction in the dictionary word editor sheet. KeyVox is a brand name and stays in English.")
                    .font(.appFont(12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("", text: $phrase)
                    .font(.appFont(14))
                    .textFieldStyle(.roundedBorder)
                    .overlay(alignment: .leading) {
                        if phrase.isEmpty {
                            Text(verbatim: "KeyVox")
                                .font(.appFont(14))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.leading, 7)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        saveFromEnter()
                    }
                    .onChange(of: phrase) { _ in
                        errorMessage = nil
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.appFont(11))
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 10) {
                AppActionButton(
                    title: String(localized: "Cancel", comment: "Button in the dictionary word editor sheet that closes it without saving."),
                    style: .secondary,
                    minWidth: DictionaryWordEditorLayout.actionButtonWidth,
                    action: { dismiss() }
                )

                AppActionButton(
                    title: mode.actionTitle,
                    style: .primary,
                    minWidth: DictionaryWordEditorLayout.actionButtonWidth,
                    isEnabled: !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: save
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .frame(width: DictionaryWordEditorLayout.width, height: DictionaryWordEditorLayout.height)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                MacAppTheme.screenBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MacAppTheme.windowStroke, lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func save() {
        do {
            switch mode {
            case .add:
                try dictionaryStore.add(phrase: phrase)
            case .edit(let entry):
                try dictionaryStore.update(id: entry.id, phrase: phrase)
            }

            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFromEnter() {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        save()
    }
}
