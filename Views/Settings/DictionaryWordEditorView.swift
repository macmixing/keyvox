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
            return "Add Dictionary Word"
        case .edit:
            return "Edit Dictionary Word"
        }
    }

    var actionTitle: String {
        switch self {
        case .add:
            return "Add Word"
        case .edit:
            return "Save Word"
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
    static let width: CGFloat = 430
    static let height: CGFloat = 160
}

struct DictionaryWordEditorView: View {
    let mode: DictionaryWordEditorMode
    @ObservedObject var dictionaryStore: DictionaryStore

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var phrase: String
    @State private var errorMessage: String?

    init(mode: DictionaryWordEditorMode, dictionaryStore: DictionaryStore) {
        self.mode = mode
        self.dictionaryStore = dictionaryStore
        _phrase = State(initialValue: mode.initialPhrase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode.title)
                    .font(.custom("Kanit Medium", size: 19))
                    .foregroundColor(.white)

                Text("Type the exact word or phrase you want KeyVox to preserve.")
                    .font(.custom("Kanit Medium", size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("", text: $phrase)
                    .font(.custom("Kanit Medium", size: 14))
                    .textFieldStyle(.roundedBorder)
                    .overlay(alignment: .leading) {
                        if phrase.isEmpty {
                            Text("KeyVox")
                                .font(.custom("Kanit Medium", size: 14))
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
                        .font(.custom("Kanit Medium", size: 11))
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(mode.actionTitle) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.regular)
            }
        }
        .padding(18)
        .frame(width: DictionaryWordEditorLayout.width, height: DictionaryWordEditorLayout.height)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.15)
                    .background(Color(white: 0.01))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
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
