import Foundation

/// A typing language's swipe vocabulary (`PredictiveData/<language>/swipe_vocabulary.txt`): the
/// words people write that its dictionary lacks, then the words its swipe dataset had people swipe
/// that the dictionary and those words lack, for swipes to decode to, each with the probability the
/// dictionary gives its words written about as often, the dataset's words the lowest of those.
/// Typing never offers them;
/// the swipe lexicon is the dictionary's words and these (`Tools/KeyVoxLanguageModel/README.md`,
/// "Swipe vocabulary").
public enum SwipeVocabulary {
    static let fileName = "swipe_vocabulary.txt"

    /// The words `engine`'s language's swipe lexicon holds: its dictionary's, in the order the
    /// dictionary stores them, then its swipe vocabulary's, likeliest first.
    public static func lexiconWords(of engine: PredictiveEngine) throws -> [SwipeLexiconBuilder.Word] {
        try engine.dictionaryWords() + words(for: engine.language)
    }

    /// `language`'s swipe vocabulary, or none when it has no file.
    static func words(for language: TypingLanguage) throws -> [SwipeLexiconBuilder.Word] {
        guard let url = language.resources.optionalURL(fileName) else { return [] }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(separator: "\n").map { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let probability = Int(fields[1]), (0...255).contains(probability) else {
                throw PredictiveKeyboardError.invalidSwipeModel(fileName)
            }
            return SwipeLexiconBuilder.Word(spelling: String(fields[0]), probability: probability, isOfferable: true)
        }
    }
}
