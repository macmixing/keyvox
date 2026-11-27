import Foundation
import KeyVoxPredictiveKeyboard

/// What the keyboard learned from the user's typing in one language, kept in the app group (see
/// `KeyboardTypingMemoryLocation`), each language in its own file. Only the memory of the language
/// the keyboard types in is loaded (`current`). Saves follow each change after a moment, off the
/// main thread. When the KeyVox app resets what the keyboard learned, in every language or in this
/// one, the memory starts over the next time the keyboard is shown. Use from the main thread.
final class KeyboardTypingMemory {
    /// The memory of the language the keyboard types in, loaded again when the language changes.
    static var current: KeyboardTypingMemory {
        let language = KeyboardTypingLanguage.current.identifier
        if let loaded = loadedCurrent, loaded.language == language {
            return loaded
        }
        let memory = KeyboardTypingMemory(language: language)
        memory.onLearnedVocabularyChange = { onCurrentLearnedVocabularyChange?() }
        loadedCurrent = memory
        return memory
    }

    /// Called when what suggestions use of the current memory changes.
    static var onCurrentLearnedVocabularyChange: (() -> Void)?

    private static var loadedCurrent: KeyboardTypingMemory?

    /// The typing language whose memory this is.
    let language: String
    let memory: TypingMemory
    /// Called when what suggestions use of the memory changes (`TypingMemory.learnedVocabulary`),
    /// so the keyboard can hand it to its suggestions.
    var onLearnedVocabularyChange: (() -> Void)?

    private static let saveDelay: TimeInterval = 1
    private let file: TypingMemoryFile?
    private let defaults: UserDefaults?
    private let saveQueue = DispatchQueue(label: "org.keyvox.keyboard.typing-memory", qos: .utility)
    private var resetGeneration: ResetGeneration
    private var isSaveScheduled = false

    /// The resets a memory was loaded under: of every language, and of its own language.
    private struct ResetGeneration: Equatable {
        let allLanguages: Int
        let language: Int
    }

    /// The memory of `language`, from its file beside the original file at `fileURL`.
    init(
        language: String = KeyboardTypingMemoryLocation.originalFileLanguage,
        fileURL: URL? = KeyboardTypingMemoryLocation.fileURL(),
        defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)
    ) {
        self.language = language
        file = fileURL
            .map { KeyboardTypingMemoryLocation.fileURL(forLanguage: language, besideOriginal: $0) }
            .map(TypingMemoryFile.init(url:))
        self.defaults = defaults
        let generation = Self.resetGeneration(of: language, in: defaults)
        resetGeneration = generation
        memory = TypingMemory(saved: file?.load(resetGeneration: generation.allLanguages) ?? TypingMemory.Saved())
        memory.onChange = { [weak self] learnedVocabularyChanged in
            self?.scheduleSave()
            if learnedVocabularyChanged {
                self?.onLearnedVocabularyChange?()
            }
        }
    }

    /// Starts over when the KeyVox app reset what the keyboard learned, in every language or in
    /// this one, since this memory was loaded.
    func adoptResetIfNeeded() {
        let generation = currentResetGeneration()
        guard generation != resetGeneration else { return }
        resetGeneration = generation
        memory.clear()
    }

    private func currentResetGeneration() -> ResetGeneration {
        Self.resetGeneration(of: language, in: defaults)
    }

    private static func resetGeneration(of language: String, in defaults: UserDefaults?) -> ResetGeneration {
        let languages = defaults?.dictionary(forKey: UserDefaultsKeys.keyboardTypingMemoryLanguageResetGenerations)
        return ResetGeneration(
            allLanguages: defaults?.integer(forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration) ?? 0,
            language: languages?[language] as? Int ?? 0
        )
    }

    private func scheduleSave() {
        guard isSaveScheduled == false else { return }
        isSaveScheduled = true
        // Held until it saves, so a memory let go when the language changes still saves its last
        // change.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDelay) { [self] in
            isSaveScheduled = false
            // A memory loaded before a reset is never saved over the reset.
            guard let file, currentResetGeneration() == resetGeneration else { return }
            let saved = memory.saved
            let generation = resetGeneration
            saveQueue.async { [self] in
                guard currentResetGeneration() == generation else { return }
                try? file.save(saved, resetGeneration: generation.allLanguages)
            }
        }
    }
}
