import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// A prediction engine with a serial queue of its own. It is created the first time work on
/// `queue` needs it and is kept up to date with the letter keys' layout, the user's vocabulary,
/// and what the keyboard learned from the user's typing from the start. Everything other than
/// `queue` is owned by `queue`.
final class KeyboardPredictionEngine {
    let queue: DispatchQueue
    private var computer: PredictionComputer?
    private var pendingGeometry: (keys: [PredictionKeyGeometry], size: CGSize)?
    private var pendingVocabulary: PersonalVocabulary?
    private var pendingLearnedWords: LearnedVocabulary?
    private var isUnavailable = false

    init(label: String, qos: DispatchQoS) {
        queue = DispatchQueue(label: label, qos: qos)
    }

    /// The engine, created the first time it is needed. Call on `queue`.
    func resolvedComputer() -> PredictionComputer? {
        if let computer { return computer }
        guard isUnavailable == false else { return nil }
        guard let engine = try? EnglishPredictiveEngine() else {
            isUnavailable = true
            return nil
        }
        let computer = PredictionComputer(engine: engine)
        if let pendingGeometry {
            computer.updateKeyboardGeometry(pendingGeometry.keys, keyboardSize: pendingGeometry.size)
            self.pendingGeometry = nil
        }
        if let pendingVocabulary {
            try? computer.updateVocabulary(pendingVocabulary)
            self.pendingVocabulary = nil
        }
        if let pendingLearnedWords {
            try? computer.updateLearnedWords(pendingLearnedWords)
            self.pendingLearnedWords = nil
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
        if let computer {
            try? computer.updateVocabulary(vocabulary)
        } else {
            pendingVocabulary = vocabulary
        }
    }

    /// Call on `queue`.
    func updateLearnedWords(_ learned: LearnedVocabulary) {
        if let computer {
            try? computer.updateLearnedWords(learned)
        } else {
            pendingLearnedWords = learned
        }
    }
}
