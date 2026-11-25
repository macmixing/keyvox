import Foundation
import KeyVoxPredictiveKeyboard

/// Writes a typing language's swipe lexicon (`swipe_lexicon.kvsl`) from its bundled dictionary,
/// for its bundled swipe model's keys, and optionally the dictionary's words as a unigram list
/// (spelling, probability, the four flag digits, shortcut count) for the swipe model tools.
enum SwipeLexiconCommand {
    static func run(_ options: HarnessCommand.SwipeLexiconOptions) throws {
        let language = try TypingLanguage.bundled(identifier: options.languageIdentifier)
        let engine = try PredictiveEngine(language: language)
        let words = try engine.dictionaryWords()
        let data = try SwipeLexiconBuilder.fileData(words: words, settings: try SwipeModelSettings.bundled(for: language))
        try data.write(to: URL(fileURLWithPath: options.outputPath))
        print("wrote \(options.outputPath) (\(data.count) bytes) from \(words.count) dictionary words")
        if let wordsPath = options.wordsPath {
            let lines = words.map { word in
                "\(word.spelling)\t\(word.probability)\t\(word.isOfferable ? "0000" : "0101")\t0\n"
            }
            try lines.joined().write(toFile: wordsPath, atomically: true, encoding: .utf8)
            print("wrote \(wordsPath)")
        }
    }
}
