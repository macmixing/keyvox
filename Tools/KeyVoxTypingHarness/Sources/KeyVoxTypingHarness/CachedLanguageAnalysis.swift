import Foundation
import KeyVoxPredictiveKeyboard

/// Memoizes engine word analyses so parameter searches score each word in context once.
final class CachedLanguageAnalysis: @unchecked Sendable {
    private let engine: EnglishPredictiveEngine
    private let lock = NSLock()
    private var analyses: [String: WordLanguageAnalysis] = [:]

    init(engine: EnglishPredictiveEngine) {
        self.engine = engine
    }

    func analyze(_ word: String, _ previousWords: [String]) throws -> WordLanguageAnalysis {
        let context = Array(previousWords.prefix(2))
        let key = ([word] + context).joined(separator: "\u{1}")
        lock.lock()
        if let cached = analyses[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let analysis = try engine.analyze(word: word, previousWords: context)
        lock.lock()
        analyses[key] = analysis
        lock.unlock()
        return analysis
    }
}
