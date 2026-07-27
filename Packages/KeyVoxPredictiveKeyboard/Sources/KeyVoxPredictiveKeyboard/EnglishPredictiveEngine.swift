import CoreGraphics
import Foundation
import KeyVoxPredictiveNative

public final class EnglishPredictiveEngine: @unchecked Sendable {
    private let nativeEngine: KVPKEngineRef
    private let accentOverlay: AccentSuggestionOverlay

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
            automaticCorrectionProbability: result.automaticCorrectionProbability,
            typedWordIsValid: result.typedWordIsValid
        )
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
        let count = max(0, min(Int(self.count), Int(KVPK_MAX_SUGGESTIONS)))
        return withUnsafePointer(to: suggestions) { pointer in
            pointer.withMemoryRebound(
                to: KVPKSuggestion.self,
                capacity: Int(KVPK_MAX_SUGGESTIONS)
            ) { suggestions in
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
}
