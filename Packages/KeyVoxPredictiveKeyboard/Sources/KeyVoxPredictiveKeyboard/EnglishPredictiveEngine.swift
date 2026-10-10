import Foundation
import KeyVoxPredictiveNative
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public final class EnglishPredictiveEngine: @unchecked Sendable {
    private let nativeEngine: KVPKEngineRef
    private let accentOverlay: AccentSuggestionOverlay
    /// Words spelled only with capitals, such as names.
    public let capitalizedSpellings: CapitalizedSpellings
    public let sentenceOpeners: SentenceOpeners
    public let unknownWordFollowers: UnknownWordFollowers

    public init() throws {
        let locator = PredictiveArtifactLocator()
        let dictionaryURL = try locator.directory(named: "candidate_v3_dict")
        let contextURL = try locator.url(name: "context_artifact_800k", extension: "bin")
        let correctionURL = try locator.url(name: "production_ranker_800k", extension: "kvtr")
        let completionURL = try locator.url(
            name: "production_completion_ranker_800k",
            extension: "kvtr"
        )
        let actionURL = try locator.url(name: "production_action_800k", extension: "kvtr")
        let accentURL = try locator.url(name: "accent_overlay", extension: "bin")
        accentOverlay = try AccentSuggestionOverlay(data: Data(contentsOf: accentURL))
        capitalizedSpellings = try CapitalizedSpellings(
            contentsOf: locator.url(name: "capitalized_spellings", extension: "txt")
        )
        sentenceOpeners = try SentenceOpeners(
            contentsOf: locator.url(name: "sentence_openers", extension: "txt")
        )
        unknownWordFollowers = try UnknownWordFollowers(
            contentsOf: locator.url(name: "unknown_word_followers", extension: "txt")
        )

        let defaultGeometry = EnglishKeyboardLayout.defaultGeometry
        let nativeGeometry = defaultGeometry.compactMap(Self.nativeGeometry)
        let createdEngine = dictionaryURL.path.withCString { dictionaryPath in
            contextURL.path.withCString { contextPath in
                correctionURL.path.withCString { correctionPath in
                    completionURL.path.withCString { completionPath in
                        actionURL.path.withCString { actionPath in
                            nativeGeometry.withUnsafeBufferPointer { keys in
                                KVPKEngineCreate(
                                    dictionaryPath,
                                    contextPath,
                                    correctionPath,
                                    completionPath,
                                    actionPath,
                                    keys.baseAddress,
                                    Int32(keys.count),
                                    1_000,
                                    400
                                )
                            }
                        }
                    }
                }
            }
        }
        guard let createdEngine else {
            throw PredictiveKeyboardError.nativeEngineInitializationFailed(Self.nativeLastError)
        }
        nativeEngine = createdEngine
    }

    deinit {
        KVPKEngineDestroy(nativeEngine)
    }

    @discardableResult
    public func updateKeyboardGeometry(
        _ geometry: [PredictionKeyGeometry],
        keyboardSize: CGSize
    ) -> Bool {
        let native = geometry.compactMap(Self.nativeGeometry)
        guard native.isEmpty == false,
              keyboardSize.width > 0,
              keyboardSize.height > 0 else {
            return false
        }
        return native.withUnsafeBufferPointer { keys in
            KVPKEngineUpdateGeometry(
                nativeEngine,
                keys.baseAddress,
                Int32(keys.count),
                Int32(keyboardSize.width.rounded()),
                Int32(keyboardSize.height.rounded())
            )
        }
    }

    public func predict(
        typedWord: String,
        previousWords: [String],
        touches: [PredictionTouch],
        mode: PredictionMode
    ) throws -> PredictionResponse {
        let normalizedTypedWord = typedWord.lowercased()
        let normalizedPreviousWords = previousWords.prefix(3).map { $0.lowercased() }
        let previous = normalizedPreviousWords.indices.contains(0)
            ? normalizedPreviousWords[0] : ""
        let older = normalizedPreviousWords.indices.contains(1)
            ? normalizedPreviousWords[1] : ""
        let oldest = normalizedPreviousWords.indices.contains(2)
            ? normalizedPreviousWords[2] : ""
        let touchX = touches.map { Int32($0.location.x.rounded()) }
        let touchY = touches.map { Int32($0.location.y.rounded()) }
        var result = KVPKPredictionResult()

        let succeeded = normalizedTypedWord.withCString { typed in
            previous.withCString { previousWord in
                older.withCString { olderWord in
                    oldest.withCString { oldestWord in
                        touchX.withUnsafeBufferPointer { x in
                            touchY.withUnsafeBufferPointer { y in
                                KVPKEnginePredict(
                                    nativeEngine,
                                    typed,
                                    previousWord,
                                    olderWord,
                                    oldestWord,
                                    x.baseAddress,
                                    y.baseAddress,
                                    Int32(min(x.count, y.count)),
                                    mode.nativeMode,
                                    &result
                                )
                            }
                        }
                    }
                }
            }
        }
        guard succeeded else {
            throw PredictiveKeyboardError.nativePredictionFailed(Self.nativeLastError)
        }

        var suggestions = result.suggestionValues
        if mode != .nextWord, normalizedTypedWord.unicodeScalars.allSatisfy(\.isASCII) {
            let existing = Set(suggestions.map { $0.word.lowercased() })
            let accentSuggestions = accentOverlay.suggestions(for: normalizedTypedWord)
                .filter { existing.contains($0.lowercased()) == false }
                .map {
                    PredictiveSuggestion(
                        word: $0,
                        nativeScore: 0,
                        nativeType: 0,
                        rankProbability: 0
                    )
                }
            let insertionIndex = min(1, suggestions.count)
            suggestions.insert(contentsOf: accentSuggestions, at: insertionIndex)
        }

        return PredictionResponse(
            suggestions: suggestions,
            twoWordSuggestions: result.twoWordSuggestionValues.map(\.word),
            automaticCorrectionProbability: result.automaticCorrectionProbability,
            typedWordIsValid: result.typedWordIsValid
        )
    }

    /// Replaces the user's own words, in the form they write them, for
    /// `personalSuggestions` to search.
    public func setPersonalWords(_ words: [String]) throws {
        let cStrings = words.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        let pointers = cStrings.map { $0.map { UnsafePointer($0) } }
        let succeeded = pointers.withUnsafeBufferPointer { words in
            KVPKEngineSetPersonalWords(nativeEngine, words.baseAddress, Int32(words.count))
        }
        guard succeeded else {
            throw PredictiveKeyboardError.nativePredictionFailed(Self.nativeLastError)
        }
    }

    /// The bundled dictionary's likeliest words that start with `prefix`, likeliest first, at
    /// most `limit`: an exact look under the prefix, much cheaper than a completion prediction.
    public func likeliestWords(startingWith prefix: String, limit: Int) throws -> [String] {
        var result = KVPKPredictionResult()
        let succeeded = prefix.lowercased().withCString { prefix in
            KVPKEngineWordsWithPrefix(nativeEngine, prefix, Int32(limit), &result)
        }
        guard succeeded else {
            throw PredictiveKeyboardError.nativePredictionFailed(Self.nativeLastError)
        }
        return result.suggestionValues.map(\.word)
    }

    /// The user's own words that the typed letters and touches could be heading for,
    /// completions and near misses alike, found the way the bundled dictionary's words are.
    public func personalSuggestions(
        typedWord: String,
        touches: [PredictionTouch]
    ) throws -> [String] {
        let touchX = touches.map { Int32($0.location.x.rounded()) }
        let touchY = touches.map { Int32($0.location.y.rounded()) }
        var result = KVPKPredictionResult()
        let succeeded = typedWord.lowercased().withCString { typed in
            touchX.withUnsafeBufferPointer { x in
                touchY.withUnsafeBufferPointer { y in
                    KVPKEnginePredictPersonal(
                        nativeEngine,
                        typed,
                        x.baseAddress,
                        y.baseAddress,
                        Int32(min(x.count, y.count)),
                        &result
                    )
                }
            }
        }
        guard succeeded else {
            throw PredictiveKeyboardError.nativePredictionFailed(Self.nativeLastError)
        }
        return result.suggestionValues.map(\.word)
    }

    public func analyze(
        word: String,
        previousWord: String? = nil
    ) throws -> WordLanguageAnalysis {
        try analyze(
            word: word,
            previousWords: previousWord.map { [$0] } ?? []
        )
    }

    public func analyze(
        word: String,
        previousWords: [String]
    ) throws -> WordLanguageAnalysis {
        let normalizedWord = word.lowercased()
        let normalizedPreviousWord = previousWords.first?.lowercased() ?? ""
        let normalizedOlderWord = previousWords.dropFirst().first?.lowercased() ?? ""
        var result = KVPKWordAnalysis()
        let succeeded = normalizedWord.withCString { wordPointer in
            normalizedPreviousWord.withCString { previousWordPointer in
                normalizedOlderWord.withCString { olderWordPointer in
                    KVPKEngineAnalyzeWord(
                        nativeEngine,
                        wordPointer,
                        previousWordPointer,
                        olderWordPointer,
                        &result
                    )
                }
            }
        }
        guard succeeded else {
            throw PredictiveKeyboardError.nativePredictionFailed(Self.nativeLastError)
        }
        return WordLanguageAnalysis(
            wordIsValid: result.wordIsValid,
            unigramLogProbability: result.unigramLogProbability,
            precedingLogProbability: result.precedingLogProbability,
            precedingPairObserved: result.precedingPairObserved,
            precedingTrigramLogProbability: result.precedingTrigramLogProbability,
            precedingTrigramObserved: result.precedingTrigramObserved
        )
    }

    private static func nativeGeometry(
        _ geometry: PredictionKeyGeometry
    ) -> KVPKKeyGeometry? {
        guard geometry.character.unicodeScalars.count == 1,
              let scalar = geometry.character.unicodeScalars.first else {
            return nil
        }
        return KVPKKeyGeometry(
            codePoint: Int32(scalar.value),
            x: Int32(geometry.frame.origin.x.rounded()),
            y: Int32(geometry.frame.origin.y.rounded()),
            width: Int32(geometry.frame.size.width.rounded()),
            height: Int32(geometry.frame.size.height.rounded())
        )
    }

    private static var nativeLastError: String {
        guard let message = KVPKEngineLastError() else { return "unknown native error" }
        return String(cString: message)
    }

}

private extension PredictionMode {
    var nativeMode: KVPKPredictionMode {
        switch self {
        case .correction:
            return KVPKPredictionModeCorrection
        case .completion:
            return KVPKPredictionModeCompletion
        case .nextWord:
            return KVPKPredictionModeNextWord
        }
    }
}

private extension KVPKPredictionResult {
    var suggestionValues: [PredictiveSuggestion] {
        withUnsafePointer(to: suggestions) { pointer in
            Self.values(of: pointer, count: count, capacity: Int(KVPK_MAX_SUGGESTIONS))
        }
    }

    var twoWordSuggestionValues: [PredictiveSuggestion] {
        withUnsafePointer(to: twoWordSuggestions) { pointer in
            Self.values(of: pointer, count: twoWordCount, capacity: Int(KVPK_MAX_TWO_WORD_SUGGESTIONS))
        }
    }

    private static func values<Suggestions>(
        of pointer: UnsafePointer<Suggestions>,
        count: Int32,
        capacity: Int
    ) -> [PredictiveSuggestion] {
        let count = max(0, min(Int(count), capacity))
        return pointer.withMemoryRebound(to: KVPKSuggestion.self, capacity: capacity) { suggestions in
            (0..<count).compactMap { index in
                let suggestion = suggestions[index]
                let word = withUnsafePointer(to: suggestion.word) { wordPointer in
                    wordPointer.withMemoryRebound(
                        to: CChar.self,
                        capacity: Int(KVPK_MAX_WORD_BYTES)
                    ) { String(cString: $0) }
                }
                guard word.isEmpty == false else { return nil }
                return PredictiveSuggestion(
                    word: word,
                    nativeScore: Int(suggestion.nativeScore),
                    nativeType: Int(suggestion.nativeType),
                    rankProbability: suggestion.rankProbability
                )
            }
        }
    }
}
