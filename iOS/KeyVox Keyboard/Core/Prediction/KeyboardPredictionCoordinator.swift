import Foundation
import KeyVoxPredictiveKeyboard

struct KeyboardAutomaticCorrectionDecision: Equatable {
    let original: String
    let replacement: String
    let probability: Double
}

final class KeyboardPredictionCoordinator {
    var onChoicesChange: (([KeyboardPredictionChoice]) -> Void)?

    private struct TextSnapshot {
        let currentWord: String
        let previousWords: [String]
    }

    private struct GeneratedState {
        let currentWord: String
        let choices: [KeyboardPredictionChoice]
        let correction: KeyboardAutomaticCorrectionDecision?
    }

    private struct EngineGeometry {
        let keys: [PredictionKeyGeometry]
        let keyboardSize: CGSize
    }

    private struct CorrectionEvaluation {
        let decision: KeyboardAutomaticCorrectionDecision?
        let reason: String
    }

    private let predictionQueue = DispatchQueue(
        label: "com.domestudios.keyvox.keyboard.prediction",
        qos: .userInitiated
    )
    private var engine: EnglishPredictiveEngine?
    private var latestGeometry: EngineGeometry?
    private var generation = 0
    private var generatedState: GeneratedState?
    private var trackedWord = ""
    private var trackedTouches: [PredictionTouch] = []
    private var protectedWordPrefix = ""
#if DEBUG
    private var hasReportedEngineFailure = false
#endif

    func refresh(
        documentContextBeforeInput: String?,
        capitalizesNextWord: Bool
    ) {
        generation += 1
        let requestedGeneration = generation
        let diagnosticRequestIdentifier = KeyboardTypingDiagnostics.nextIdentifier()
        let diagnosticStartedAt = ProcessInfo.processInfo.systemUptime
        let snapshot = Self.textSnapshot(from: documentContextBeforeInput)
        synchronizeTouches(currentWord: snapshot.currentWord)
        synchronizeProtectedInput(currentWord: snapshot.currentWord)
        let touches = trackedWord == snapshot.currentWord.lowercased()
            ? trackedTouches
            : []
        let protectsLiteral = protectedWordPrefix.isEmpty == false
        KeyboardTypingDiagnostics.log("prediction_request", fields: [
            "request_id": diagnosticRequestIdentifier,
            "generation": requestedGeneration,
            "current_word": snapshot.currentWord,
            "previous_words": snapshot.previousWords,
            "touch_count": touches.count,
            "protects_literal": protectsLiteral,
            "capitalizes_next_word": capitalizesNextWord,
        ])

        predictionQueue.async { [weak self] in
            guard let self else { return }
            KeyboardTypingDiagnostics.log("prediction_worker_begin", fields: [
                "request_id": diagnosticRequestIdentifier,
                "queue_delay_ms": Self.diagnosticMilliseconds(since: diagnosticStartedAt),
            ])
            let state = self.generateState(
                snapshot: snapshot,
                touches: touches,
                protectsLiteral: protectsLiteral,
                capitalizesNextWord: capitalizesNextWord,
                diagnosticRequestIdentifier: diagnosticRequestIdentifier
            )
            KeyboardTypingDiagnostics.log("prediction_worker_end", fields: [
                "request_id": diagnosticRequestIdentifier,
                "duration_ms": Self.diagnosticMilliseconds(since: diagnosticStartedAt),
                "choices": state.choices.map(\.text),
                "choice_kinds": state.choices.map { String(describing: $0.kind) },
                "correction": state.correction?.replacement ?? "none",
            ])
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.generation == requestedGeneration else {
                    KeyboardTypingDiagnostics.log("prediction_discarded", fields: [
                        "request_id": diagnosticRequestIdentifier,
                        "requested_generation": requestedGeneration,
                        "current_generation": self.generation,
                    ])
                    return
                }
                self.generatedState = state
                KeyboardTypingDiagnostics.log("prediction_published", fields: [
                    "request_id": diagnosticRequestIdentifier,
                    "total_ms": Self.diagnosticMilliseconds(since: diagnosticStartedAt),
                    "choices": state.choices.map(\.text),
                ])
                self.onChoicesChange?(state.choices)
            }
        }
    }

    func recordCharacter(
        _ value: String,
        location: CGPoint,
        isLongPressAlternate: Bool,
        documentContextBeforeInput: String?
    ) {
        let snapshot = Self.textSnapshot(from: documentContextBeforeInput)
        let normalizedValue = value.lowercased()
        let normalizedWord = snapshot.currentWord.lowercased()
        if isLongPressAlternate {
            protectedWordPrefix = normalizedWord
            trackedWord = ""
            trackedTouches = []
            return
        }
        synchronizeProtectedInput(currentWord: normalizedWord)
        let canTrackTouch = normalizedValue.count == 1
            && normalizedValue.unicodeScalars.allSatisfy(\.isASCII)
        guard canTrackTouch else {
            trackedWord = ""
            trackedTouches = []
            return
        }
        if normalizedWord == trackedWord + normalizedValue {
            trackedWord = normalizedWord
            trackedTouches.append(PredictionTouch(location: location))
        } else if normalizedWord == normalizedValue {
            trackedWord = normalizedWord
            trackedTouches = [PredictionTouch(location: location)]
        } else {
            trackedWord = ""
            trackedTouches = []
        }
    }

    func synchronizeAfterDeletion(documentContextBeforeInput: String?) {
        let currentWord = Self.textSnapshot(from: documentContextBeforeInput)
            .currentWord
            .lowercased()
        synchronizeTouches(currentWord: currentWord)
        synchronizeProtectedInput(currentWord: currentWord)
    }

    func automaticCorrectionDecision(
        documentContextBeforeInput: String?
    ) -> KeyboardAutomaticCorrectionDecision? {
        let currentWord = Self.textSnapshot(from: documentContextBeforeInput).currentWord
        guard generatedState?.currentWord == currentWord else {
            KeyboardTypingDiagnostics.log("correction_lookup", fields: [
                "current_word": currentWord,
                "generated_word": generatedState?.currentWord ?? "none",
                "result": "stale_or_missing_prediction",
            ])
            return nil
        }
        let decision = generatedState?.correction
        KeyboardTypingDiagnostics.log("correction_lookup", fields: [
            "current_word": currentWord,
            "result": decision == nil ? "no_decision" : "decision_available",
            "replacement": decision?.replacement ?? "none",
            "probability": decision?.probability ?? 0,
        ])
        return decision
    }

    func currentWord(documentContextBeforeInput: String?) -> String {
        Self.textSnapshot(from: documentContextBeforeInput).currentWord
    }

    func reset() {
        generation += 1
        generatedState = nil
        trackedWord = ""
        trackedTouches = []
        protectedWordPrefix = ""
        onChoicesChange?([])
    }

    func updateGeometry(
        _ geometry: [KeyboardCharacterKeyGeometry],
        keyboardSize: CGSize
    ) {
        let predictionGeometry = geometry.map {
            PredictionKeyGeometry(character: $0.character, frame: $0.frame)
        }
        predictionQueue.async { [weak self] in
            guard let self else { return }
            let geometry = EngineGeometry(
                keys: predictionGeometry,
                keyboardSize: keyboardSize
            )
            self.latestGeometry = geometry
            if let engine = self.engine {
                _ = engine.updateKeyboardGeometry(
                    geometry.keys,
                    keyboardSize: geometry.keyboardSize
                )
            }
        }
    }

    private func generateState(
        snapshot: TextSnapshot,
        touches: [PredictionTouch],
        protectsLiteral: Bool,
        capitalizesNextWord: Bool,
        diagnosticRequestIdentifier: Int
    ) -> GeneratedState {
        do {
            let engine = try resolvedEngine()
            if snapshot.currentWord.isEmpty {
                guard snapshot.previousWords.isEmpty == false else {
                    return GeneratedState(currentWord: "", choices: [], correction: nil)
                }
                let response = try engine.predict(
                    typedWord: "",
                    previousWords: snapshot.previousWords,
                    touches: [],
                    mode: .nextWord
                )
                logPredictionResponse(
                    response,
                    mode: "next_word",
                    requestIdentifier: diagnosticRequestIdentifier
                )
                let choices = response.suggestions.prefix(3).map {
                    KeyboardPredictionChoice(
                        text: capitalizesNextWord
                            ? Self.capitalizeFirstLetter(of: $0.word)
                            : $0.word,
                        kind: .nextWord
                    )
                }
                return GeneratedState(currentWord: "", choices: choices, correction: nil)
            }

            let containsDirectSpecialInput = snapshot.currentWord.unicodeScalars
                .contains { $0.isASCII == false }
            if containsDirectSpecialInput {
                return GeneratedState(
                    currentWord: snapshot.currentWord,
                    choices: [KeyboardPredictionChoice(text: snapshot.currentWord, kind: .literal)],
                    correction: nil
                )
            }

            let completionResponse = try engine.predict(
                typedWord: snapshot.currentWord,
                previousWords: snapshot.previousWords,
                touches: touches,
                mode: .completion
            )
            logPredictionResponse(
                completionResponse,
                mode: "completion",
                requestIdentifier: diagnosticRequestIdentifier
            )
            let correctionResponse = try engine.predict(
                typedWord: snapshot.currentWord,
                previousWords: snapshot.previousWords,
                touches: touches,
                mode: .correction
            )
            logPredictionResponse(
                correctionResponse,
                mode: "correction",
                requestIdentifier: diagnosticRequestIdentifier
            )
            let choices = Self.makeChoices(
                literal: snapshot.currentWord,
                completionSuggestions: completionResponse.suggestions,
                correctionResponse: correctionResponse
            )
            let correctionEvaluation = Self.makeCorrectionEvaluation(
                original: snapshot.currentWord,
                response: correctionResponse,
                protectsLiteral: protectsLiteral
            )
            KeyboardTypingDiagnostics.log("correction_evaluation", fields: [
                "request_id": diagnosticRequestIdentifier,
                "original": snapshot.currentWord,
                "reason": correctionEvaluation.reason,
                "typed_word_valid": correctionResponse.typedWordIsValid,
                "probability": correctionResponse.automaticCorrectionProbability,
                "threshold": EnglishPredictiveEngine.automaticCorrectionThreshold,
                "replacement": correctionEvaluation.decision?.replacement ?? "none",
            ])
            return GeneratedState(
                currentWord: snapshot.currentWord,
                choices: choices,
                correction: correctionEvaluation.decision
            )
        } catch {
            reportEngineFailure(error)
            let choices = snapshot.currentWord.isEmpty
                ? []
                : [KeyboardPredictionChoice(text: snapshot.currentWord, kind: .literal)]
            return GeneratedState(
                currentWord: snapshot.currentWord,
                choices: choices,
                correction: nil
            )
        }
    }

    private func logPredictionResponse(
        _ response: PredictionResponse,
        mode: String,
        requestIdentifier: Int
    ) {
        KeyboardTypingDiagnostics.log("prediction_response", fields: [
            "request_id": requestIdentifier,
            "mode": mode,
            "typed_word_valid": response.typedWordIsValid,
            "automatic_correction_probability": response.automaticCorrectionProbability,
            "suggestions": response.suggestions.map { suggestion in
                [
                    "word": suggestion.word,
                    "native_score": suggestion.nativeScore,
                    "native_type": suggestion.nativeType,
                    "rank_probability": suggestion.rankProbability,
                ] as [String: Any]
            },
        ])
    }

    private func reportEngineFailure(_ error: Error) {
#if DEBUG
        guard hasReportedEngineFailure == false else { return }
        hasReportedEngineFailure = true
        KeyboardTypingDiagnostics.log("prediction_engine_failure", fields: [
            "error": String(reflecting: error),
        ])
#endif
    }

    private func resolvedEngine() throws -> EnglishPredictiveEngine {
        if let engine { return engine }
        let createdEngine = try EnglishPredictiveEngine()
        if let latestGeometry {
            _ = createdEngine.updateKeyboardGeometry(
                latestGeometry.keys,
                keyboardSize: latestGeometry.keyboardSize
            )
        }
        engine = createdEngine
        return createdEngine
    }

    private func synchronizeTouches(currentWord: String) {
        let normalized = currentWord.lowercased()
        guard trackedWord.hasPrefix(normalized), normalized.count <= trackedTouches.count else {
            if normalized != trackedWord {
                trackedWord = ""
                trackedTouches = []
            }
            return
        }
        trackedWord = normalized
        trackedTouches = Array(trackedTouches.prefix(normalized.count))
    }

    private func synchronizeProtectedInput(currentWord: String) {
        guard protectedWordPrefix.isEmpty == false else { return }
        if currentWord.lowercased().hasPrefix(protectedWordPrefix) == false {
            protectedWordPrefix = ""
        }
    }

    private static func makeCorrectionEvaluation(
        original: String,
        response: PredictionResponse,
        protectsLiteral: Bool
    ) -> CorrectionEvaluation {
        guard response.typedWordIsValid == false else {
            return CorrectionEvaluation(decision: nil, reason: "typed_word_valid")
        }
        guard protectsLiteral == false else {
            return CorrectionEvaluation(decision: nil, reason: "literal_protected")
        }
        guard allowsAutomaticCorrectionCase(for: original) else {
            return CorrectionEvaluation(decision: nil, reason: "unsupported_case")
        }
        guard response.automaticCorrectionProbability
            >= EnglishPredictiveEngine.automaticCorrectionThreshold else {
            return CorrectionEvaluation(decision: nil, reason: "below_threshold")
        }
        guard let suggestion = response.suggestions.first else {
            return CorrectionEvaluation(decision: nil, reason: "no_suggestion")
        }
        let replacement = applyCase(of: original, to: suggestion.word)
        guard replacement.caseInsensitiveCompare(original) != .orderedSame else {
            return CorrectionEvaluation(decision: nil, reason: "same_as_typed")
        }
        return CorrectionEvaluation(
            decision: KeyboardAutomaticCorrectionDecision(
                original: original,
                replacement: replacement,
                probability: response.automaticCorrectionProbability
            ),
            reason: "accepted"
        )
    }

    private static func diagnosticMilliseconds(since start: TimeInterval) -> Double {
        ((ProcessInfo.processInfo.systemUptime - start) * 100_000).rounded() / 100
    }

    private static func allowsAutomaticCorrectionCase(for word: String) -> Bool {
        word == word.lowercased()
    }

    private static func makeChoices(
        literal: String,
        completionSuggestions: [PredictiveSuggestion],
        correctionResponse: PredictionResponse
    ) -> [KeyboardPredictionChoice] {
        var observed = Set([literal.lowercased()])
        var candidates: [KeyboardPredictionChoice] = []

        if correctionResponse.typedWordIsValid == false,
           literal.count >= 2,
           let correction = correctionResponse.suggestions.first {
            let value = applyCase(of: literal, to: correction.word)
            if observed.insert(value.lowercased()).inserted {
                candidates.append(
                    KeyboardPredictionChoice(text: value, kind: .correction)
                )
            }
        }

        candidates.append(contentsOf: completionSuggestions.compactMap { suggestion in
            let value = applyCase(of: literal, to: suggestion.word)
            guard observed.insert(value.lowercased()).inserted else { return nil }
            let kind: KeyboardPredictionChoice.Kind = value.unicodeScalars.contains {
                $0.isASCII == false
            } ? .accent : .completion
            return KeyboardPredictionChoice(text: value, kind: kind)
        })
        let literalChoice = KeyboardPredictionChoice(text: literal, kind: .literal)
        guard candidates.isEmpty == false else { return [literalChoice] }
        if candidates.count == 1 {
            return [candidates[0], literalChoice]
        }
        return [candidates[0], literalChoice, candidates[1]]
    }

    private static func applyCase(of original: String, to suggestion: String) -> String {
        guard original.isEmpty == false else { return suggestion }
        if original == original.uppercased(), original != original.lowercased() {
            return suggestion.uppercased()
        }
        guard original.first?.isUppercase == true,
              let first = suggestion.first else {
            return suggestion
        }
        return first.uppercased() + suggestion.dropFirst()
    }

    private static func capitalizeFirstLetter(of word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    private static func textSnapshot(from context: String?) -> TextSnapshot {
        let context = context ?? ""
        var currentCharacters: [Character] = []
        var cursor = context.endIndex
        while cursor > context.startIndex {
            let previousIndex = context.index(before: cursor)
            let character = context[previousIndex]
            guard character.isLetter || character == "'" || character == "’" else { break }
            currentCharacters.append(character)
            cursor = previousIndex
        }
        let currentWord = String(currentCharacters.reversed())
        let earlierContext = String(context[..<cursor])
        let contextualSegment: String
        if let boundary = earlierContext.lastIndex(where: { character in
            character.isNewline || ".!?".contains(character)
        }) {
            contextualSegment = String(earlierContext[earlierContext.index(after: boundary)...])
        } else {
            contextualSegment = earlierContext
        }
        let previousWords = contextualSegment
            .split { character in
                character.isLetter == false && character != "'" && character != "’"
            }
            .suffix(3)
            .reversed()
            .map(String.init)
        return TextSnapshot(currentWord: currentWord, previousWords: previousWords)
    }
}
