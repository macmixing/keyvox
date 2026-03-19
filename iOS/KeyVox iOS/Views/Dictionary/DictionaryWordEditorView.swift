import Combine
import SwiftUI
import KeyVoxCore

struct DictionaryWordEditorView: View {
    private enum Layout {
        static let addDetentHeightiOS18: CGFloat = 167
        static let addDetentHeightiOS26: CGFloat = 205
        static let editDetentHeight: CGFloat = 180
    }

    let mode: DictionaryWordEditorMode
    let onSave: () -> Void

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var phrase: String
    @State private var errorMessage: String?
    @State private var measuredErrorHeight: CGFloat = 0
    @StateObject private var keyboardObserver = KeyboardObserver()

    init(mode: DictionaryWordEditorMode, onSave: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSave = onSave
        _phrase = State(initialValue: mode.initialPhrase)
    }

    private var trimmedPhrase: String {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bottomPadding: CGFloat {
        keyboardObserver.isKeyboardVisible ? 0 : 30
    }

    private var sheetHeight: CGFloat {
        let baseHeight: CGFloat
        if mode.showsDescription {
            if #available(iOS 26.0, *) {
                baseHeight = Layout.addDetentHeightiOS26
            } else {
                baseHeight = Layout.addDetentHeightiOS18
            }
        } else {
            baseHeight = Layout.editDetentHeight
        }
        return baseHeight + (errorMessage == nil ? 0 : measuredErrorHeight) + bottomPadding
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    AutoFocusTextField(
                        text: $phrase,
                        placeholder: "KeyVox",
                        onSubmit: submit
                    )
                    .frame(height: 44)
                    .onChange(of: phrase) { _, _ in
                        errorMessage = nil
                        measuredErrorHeight = 0
                    }
                }
                .scrollDisabled(true)
                .padding(.top, -18)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, -15)
                        .padding(.bottom, 15)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: DictionaryWordEditorErrorHeightPreferenceKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )
                }

                if mode.showsDescription {
                    Text("Add custom words, email addresses, and short phrases to improve transcription accuracy.")
                        .font(.appFont(12))
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: 380)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, -10)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 16)
                }
            }
            .onPreferenceChange(DictionaryWordEditorErrorHeightPreferenceKey.self) { height in
                measuredErrorHeight = height
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
                    .tint(AppTheme.accent)
                    .disabled(trimmedPhrase.isEmpty)
                }
            }
        }
        .presentationDetents([.height(sheetHeight)])
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

            if let event = DictionarySaveHapticsDecision.successEvent(isAddingNewWord: mode.isAdd) {
                appHaptics.emit(event)
            }
            onSave()
            dismiss()
        } catch {
            appHaptics.emit(DictionarySaveHapticsDecision.failureEvent())
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

private extension DictionaryWordEditorMode {
    var isAdd: Bool {
        if case .add = self {
            return true
        }

        return false
    }
}

private struct DictionaryWordEditorErrorHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
