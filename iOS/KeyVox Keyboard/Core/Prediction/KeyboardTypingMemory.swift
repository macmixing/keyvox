import Foundation
import KeyVoxPredictiveKeyboard

/// What the keyboard learned from the user's typing, shared by every keyboard view while the
/// extension runs and kept in the app group (see `KeyboardTypingMemoryLocation`). Saves follow
/// each change after a moment, off the main thread. When the KeyVox app resets what the keyboard
/// learned, the memory starts over the next time the keyboard is shown. Use from the main thread.
final class KeyboardTypingMemory {
    static let shared = KeyboardTypingMemory()

    let memory: TypingMemory
    /// Called when what suggestions use of the memory changes (`TypingMemory.learnedVocabulary`),
    /// so the keyboard can hand it to its suggestions.
    var onLearnedVocabularyChange: (() -> Void)?

    private static let saveDelay: TimeInterval = 1
    private let file: TypingMemoryFile?
    private let defaults: UserDefaults?
    private let saveQueue = DispatchQueue(label: "org.keyvox.keyboard.typing-memory", qos: .utility)
    private var resetGeneration: Int
    private var isSaveScheduled = false

    init(
        fileURL: URL? = KeyboardTypingMemoryLocation.fileURL(),
        defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)
    ) {
        file = fileURL.map(TypingMemoryFile.init(url:))
        self.defaults = defaults
        let generation = defaults?.integer(forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration) ?? 0
        resetGeneration = generation
        memory = TypingMemory(saved: file?.load(resetGeneration: generation) ?? TypingMemory.Saved())
        memory.onChange = { [weak self] learnedVocabularyChanged in
            self?.scheduleSave()
            if learnedVocabularyChanged {
                self?.onLearnedVocabularyChange?()
            }
        }
    }

    /// Starts over when the KeyVox app reset what the keyboard learned since this memory was
    /// loaded.
    func adoptResetIfNeeded() {
        let generation = currentResetGeneration()
        guard generation != resetGeneration else { return }
        resetGeneration = generation
        memory.clear()
    }

    private func currentResetGeneration() -> Int {
        defaults?.integer(forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration) ?? 0
    }

    private func scheduleSave() {
        guard isSaveScheduled == false else { return }
        isSaveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDelay) { [weak self] in
            guard let self else { return }
            self.isSaveScheduled = false
            // A memory loaded before a reset is never saved over the reset.
            guard let file = self.file, self.currentResetGeneration() == self.resetGeneration else { return }
            let saved = self.memory.saved
            let generation = self.resetGeneration
            self.saveQueue.async { [weak self] in
                guard self?.currentResetGeneration() == generation else { return }
                try? file.save(saved, resetGeneration: generation)
            }
        }
    }
}
