import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// A prediction engine with a serial queue of its own for one typing language. It is created the
/// first time work on `queue` needs it and is kept up to date with the letter keys' layout, the
/// user's vocabulary, and what the keyboard learned from the user's typing in the language from the
/// start. Changing the language lets go of the engine, so only one language's files stay loaded,
/// and the next one is created for the new language with the same vocabulary and the learned words
/// handed over last, which the host replaces with the new language's. Everything other than `queue`
/// is owned by `queue`.
final class KeyboardPredictionEngine {
    let queue: DispatchQueue
    private var language: TypingLanguage
    private var computer: PredictionComputer?
    private var pendingGeometry: (keys: [PredictionKeyGeometry], size: CGSize)?
    private var vocabulary: PersonalVocabulary?
    private var learnedWords: LearnedVocabulary?
    private var isUnavailable = false

    init(language: TypingLanguage, label: String, qos: DispatchQoS) {
        self.language = language
        queue = DispatchQueue(label: label, qos: qos)
    }

    /// Types in `language` from now on: the engine for the previous one is let go, and the letter
    /// keys' frames are waited for again, the new language's default layout standing in until they
    /// come. Call on `queue`.
    func setLanguage(_ language: TypingLanguage) {
        self.language = language
        computer = nil
        pendingGeometry = nil
        isUnavailable = false
    }

    /// The engine, created the first time it is needed. Call on `queue`.
    func resolvedComputer() -> PredictionComputer? {
        if let computer { return computer }
        guard isUnavailable == false else { return nil }
        guard let engine = try? PredictiveEngine(language: language) else {
            isUnavailable = true
            return nil
        }
        let computer = PredictionComputer(engine: engine)
        if let pendingGeometry {
            computer.updateKeyboardGeometry(pendingGeometry.keys, keyboardSize: pendingGeometry.size)
            self.pendingGeometry = nil
        }
        if let vocabulary {
            try? computer.updateVocabulary(vocabulary)
        }
        if let learnedWords {
            try? computer.updateLearnedWords(learnedWords)
        }
        self.computer = computer
        return computer
    }

    /// Call on `queue`.
    func updateKeyboardGeometry(_ keys: [PredictionKeyGeometry], keyboardSize: CGSize) {
        if let computer {
            computer.updateKeyboardGeometry(keys, keyboardSize: keyboardSize)
        } else {
            pendingGeometry = (keys, keyboardSize)
        }
    }

    /// Call on `queue`.
    func updateVocabulary(_ vocabulary: PersonalVocabulary) {
        self.vocabulary = vocabulary
        try? computer?.updateVocabulary(vocabulary)
    }

    /// Call on `queue`.
    func updateLearnedWords(_ learned: LearnedVocabulary) {
        learnedWords = learned
        try? computer?.updateLearnedWords(learned)
    }
}
