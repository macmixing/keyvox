import Combine
import SwiftUI
import KeyVoxCore

struct DictionaryWordEditorView: View {
    private enum Layout {
        static let baseDetentHeight: CGFloat = 200
    }

    let mode: DictionaryWordEditorMode

    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var phrase: String
    @State private var errorMessage: String?
    @StateObject private var keyboardObserver = KeyboardObserver()

    init(mode: DictionaryWordEditorMode) {
        self.mode = mode
        _phrase = State(initialValue: mode.initialPhrase)
    }

    private var trimmedPhrase: String {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bottomPadding: CGFloat {
        keyboardObserver.isKeyboardVisible ? 0 : 30
    }

    var body: some View {
        NavigationStack {
            Form {
                AutoFocusTextField(
                    text: $phrase,
                    placeholder: "KeyVox",
                    onSubmit: submit
                )
                .frame(height: 44)
                .onChange(of: phrase) { _, _ in
                    errorMessage = nil
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode.actionTitle) {
                        submit()
                    }
                    .tint(iOSAppTheme.accent)
                    .disabled(trimmedPhrase.isEmpty)
                }
            }
        }
        .presentationDetents([.height(Layout.baseDetentHeight + bottomPadding)])
        .presentationDragIndicator(.visible)
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

    private func submit() {
        let cleanedPhrase = trimmedPhrase
        guard !cleanedPhrase.isEmpty else { return }
        phrase = cleanedPhrase

        // Begin dismissal before the save side effects run.
        DispatchQueue.main.async {
            save()
        }
    }
}
