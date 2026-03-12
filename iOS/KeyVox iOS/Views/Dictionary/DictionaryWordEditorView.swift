import SwiftUI
import KeyVoxCore

struct DictionaryWordEditorView: View {
    let mode: DictionaryWordEditorMode

    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var phrase: String
    @State private var errorMessage: String?

    init(mode: DictionaryWordEditorMode) {
        self.mode = mode
        _phrase = State(initialValue: mode.initialPhrase)
    }

    var body: some View {
        NavigationStack {
            iOSAppScrollScreen {
                iOSAppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type the exact word or phrase you want KeyVox to preserve.")
                            .font(.appFont(12))
                            .foregroundStyle(.secondary)

                        TextField("KeyVox", text: $phrase, axis: .vertical)
                            .font(.appFont(16))
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .lineLimit(1...3)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onSubmit(saveFromSubmit)
                            .onChange(of: phrase) { _, _ in
                                errorMessage = nil
                            }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.appFont(12))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.appFont(14))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.actionTitle) {
                        save()
                    }
                    .font(.appFont(14))
                }
            }
        }
        .presentationDetents([.medium])
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

    private func saveFromSubmit() {
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { return }
        save()
    }
}
