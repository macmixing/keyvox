import Foundation
import KeyVoxPredictiveNative

/// A typing language's bundled dictionary opened on its own, without the context model, rankers,
/// or keys `PredictiveEngine` loads, only to ask which words it has. Its file stays mapped while
/// the value is kept and is let go with it.
final class TypingLanguageDictionary {
    private let dictionary: KVPKDictionaryRef

    /// The dictionary `language` types with: its own, or the one a regional variant shares.
    init(language: TypingLanguage) throws {
        let url = try language.resources.dataDirectory("dictionary")
        guard let dictionary = url.path.withCString(KVPKDictionaryOpen) else {
            throw PredictiveKeyboardError.missingArtifact("dictionary")
        }
        self.dictionary = dictionary
    }

    deinit {
        KVPKDictionaryClose(dictionary)
    }

    /// Whether the dictionary has `word`, in lowercase, as `PredictiveEngine.analyze(word:)` says it
    /// of a word with `wordIsValid`.
    func hasWord(_ word: String) -> Bool {
        let codePoints = word.lowercased().unicodeScalars.map { Int32(bitPattern: $0.value) }
        return codePoints.withUnsafeBufferPointer { buffer in
            KVPKDictionaryHasWord(dictionary, buffer.baseAddress, Int32(buffer.count))
        }
    }
}
