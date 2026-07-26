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
        let previousWords: [String]
        let choices: [KeyboardPredictionChoice]
        let correction: KeyboardAutomaticCorrectionDecision?
        let correctionResponse: PredictionResponse?
        let protectsLiteral: Bool
    }

    private struct DeferredWord {
        let original: String
        let previousWords: [String]
        let correctionResponse: PredictionResponse?
        let protectsLiteral: Bool
    }

    private struct EngineGeometry {
        let keys: [PredictionKeyGeometry]
        let keyboardSize: CGSize
    }

    private struct CorrectionEvaluation {
        let decision: KeyboardAutomaticCorrectionDecision?
        let reason: String
        let selectedProbability: Double
        let competingProbability: Double
    }

    private let predictionQueue = DispatchQueue(
        label: "com.domestudios.keyvox.keyboard.prediction",
        qos: .userInitiated
    )
    private var engine: EnglishPredictiveEngine?
    private var latestGeometry: EngineGeometry?
    private let generationLock = NSLock()
    private var generation = 0
    private var generatedState: GeneratedState?
    private var trackedWord = ""
    private var trackedTouches: [PredictionTouch] = []
    private var protectedWordPrefix = ""
    private var supplementaryLexicon = KeyboardSupplementaryLexicon.empty
    private var userDictionaryPhrases: [String] = []
    private var userDictionarySuggestionIndex = KeyboardUserDictionarySuggestionIndex.empty
    private var deferredWords: [DeferredWord] = []
#if DEBUG
    private var hasReportedEngineFailure = false
#endif

    func refresh(
        documentContextBeforeInput: String?,
        capitalizesNextWord: Bool
    ) {
        let requestedGeneration = advanceGeneration()
        let diagnosticRequestIdentifier = KeyboardTypingDiagnostics.nextIdentifier()
        let diagnosticStartedAt = ProcessInfo.processInfo.systemUptime
        let snapshot = Self.textSnapshot(from: documentContextBeforeInput)
        synchronizeTouches(currentWord: snapshot.currentWord)
        synchronizeProtectedInput(currentWord: snapshot.currentWord)
        let touches = trackedWord == snapshot.currentWord.lowercased()
            ? trackedTouches
            : []
        let protectsLiteral = protectedWordPrefix.isEmpty == false
        let supplementaryLexicon = supplementaryLexicon
        let userDictionarySuggestionIndex = userDictionarySuggestionIndex
        let deferredWords = alignedDeferredWords(
            with: snapshot.previousWords
        )
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
            guard self.currentGeneration() == requestedGeneration else {
                KeyboardTypingDiagnostics.log("prediction_skipped", fields: [
                    "request_id": diagnosticRequestIdentifier,
                    "requested_generation": requestedGeneration,
                    "current_generation": self.currentGeneration(),
                    "reason": "superseded_before_work",
                ])
                return
            }
            KeyboardTypingDiagnostics.log("prediction_worker_begin", fields: [
                "request_id": diagnosticRequestIdentifier,
                "queue_delay_ms": Self.diagnosticMilliseconds(since: diagnosticStartedAt),
            ])
            let state = self.generateState(
                snapshot: snapshot,
                touches: touches,
                protectsLiteral: protectsLiteral,
                supplementaryLexicon: supplementaryLexicon,
                userDictionarySuggestionIndex: userDictionarySuggestionIndex,
                deferredWords: deferredWords,
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
                let currentGeneration = self.currentGeneration()
                guard currentGeneration == requestedGeneration else {
                    let retainedResponse = self.retainDeferredResponse(from: state)
                    KeyboardTypingDiagnostics.log("prediction_discarded", fields: [
                        "request_id": diagnosticRequestIdentifier,
                        "requested_generation": requestedGeneration,
                        "current_generation": currentGeneration,
                        "retained_for_rolling_context": retainedResponse,
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
        advanceGeneration()
        generatedState = nil
        trackedWord = ""
        trackedTouches = []
        protectedWordPrefix = ""
        deferredWords = []
        onChoicesChange?([])
    }

    func advanceAfterWordBoundary(documentContextBeforeInput: String?) {
        advanceGeneration()
        let snapshot = Self.textSnapshot(from: documentContextBeforeInput)
        guard snapshot.currentWord.isEmpty,
              let completedWord = snapshot.previousWords.first else {
            reset()
            return
        }
        let matchingState = generatedState?.currentWord.caseInsensitiveCompare(completedWord)
                == .orderedSame
            ? generatedState
            : nil
        let priorHistory = alignedDeferredWords(
            with: Array(snapshot.previousWords.dropFirst())
        )
        deferredWords = Array((priorHistory + [DeferredWord(
            original: completedWord,
            previousWords: Array(snapshot.previousWords.dropFirst().prefix(3)),
            correctionResponse: matchingState?.correctionResponse,
            protectsLiteral: matchingState?.protectsLiteral == true
                || supplementaryLexicon.contains(completedWord)
        )]).suffix(5))
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

    func updateSupplementaryLexicon(_ supplementaryLexicon: KeyboardSupplementaryLexicon) {
        advanceGeneration()
        generatedState = nil
        self.supplementaryLexicon = supplementaryLexicon
    }

    func updateUserDictionaryPhrases(_ phrases: [String]) {
        guard phrases != userDictionaryPhrases else { return }
        advanceGeneration()
        generatedState = nil
        userDictionaryPhrases = phrases
        userDictionarySuggestionIndex = KeyboardUserDictionarySuggestionIndex(phrases: phrases)
    }

    private func generateState(
        snapshot: TextSnapshot,
        touches: [PredictionTouch],
        protectsLiteral: Bool,
        supplementaryLexicon: KeyboardSupplementaryLexicon,
        userDictionarySuggestionIndex: KeyboardUserDictionarySuggestionIndex,
        deferredWords: [DeferredWord],
        capitalizesNextWord: Bool,
        diagnosticRequestIdentifier: Int
    ) -> GeneratedState {
        do {
            let engine = try resolvedEngine()
            if snapshot.currentWord.isEmpty {
                guard snapshot.previousWords.isEmpty == false else {
                    return GeneratedState(
                        currentWord: "",
                        previousWords: snapshot.previousWords,
                        choices: [],
                        correction: nil,
                        correctionResponse: nil,
                        protectsLiteral: false
                    )
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
                return GeneratedState(
                    currentWord: "",
                    previousWords: snapshot.previousWords,
                    choices: choices,
                    correction: nil,
                    correctionResponse: nil,
                    protectsLiteral: false
                )
            }

            let containsDirectSpecialInput = snapshot.currentWord.unicodeScalars
                .contains { $0.isASCII == false }
            if containsDirectSpecialInput {
                return GeneratedState(
                    currentWord: snapshot.currentWord,
                    previousWords: snapshot.previousWords,
                    choices: [KeyboardPredictionChoice(text: snapshot.currentWord, kind: .literal)],
                    correction: nil,
                    correctionResponse: nil,
                    protectsLiteral: true
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
            let userDictionarySuggestion = userDictionarySuggestionIndex
                .preferredSuggestion(for: snapshot.currentWord)
            if let userDictionarySuggestion {
                KeyboardTypingDiagnostics.log("user_dictionary_suggestion", fields: [
                    "request_id": diagnosticRequestIdentifier,
                    "typed_word": snapshot.currentWord,
                    "suggestion": userDictionarySuggestion,
                ])
            }
            let choices = Self.makeChoices(
                literal: snapshot.currentWord,
                completionSuggestions: completionResponse.suggestions,
                correctionResponse: correctionResponse,
                supplementaryLexicon: supplementaryLexicon,
                userDictionarySuggestion: userDictionarySuggestion
            )
            var correctionEvaluation = Self.makeCorrectionEvaluation(
                original: snapshot.currentWord,
                response: correctionResponse,
                protectsLiteral: protectsLiteral,
                supplementaryLexicon: supplementaryLexicon
            )
            if correctionEvaluation.decision == nil,
               snapshot.currentWord.count == 4 {
                let stablePrefix = String(snapshot.currentWord.prefix(2))
                let prefixResponse = try engine.predict(
                    typedWord: stablePrefix,
                    previousWords: snapshot.previousWords,
                    touches: [],
                    mode: .completion
                )
                if let contextualWordCorrection = try EnglishContextualCorrectionPolicy
                    .fourLetterWordCorrection(
                        typedWord: snapshot.currentWord,
                        prefixCompletionSuggestions: prefixResponse.suggestions,
                        previousWords: snapshot.previousWords,
                        analyze: { try engine.analyze(word: $0, previousWords: $1) }
                    ) {
                    correctionEvaluation = CorrectionEvaluation(
                        decision: KeyboardAutomaticCorrectionDecision(
                            original: snapshot.currentWord,
                            replacement: Self.applyCase(
                                of: snapshot.currentWord,
                                to: contextualWordCorrection.word
                            ),
                            probability: contextualWordCorrection.rankProbability
                        ),
                        reason: AutomaticCorrectionSelectionReason.contextualWordRecovery.rawValue,
                        selectedProbability: contextualWordCorrection.rankProbability,
                        competingProbability: 0
                    )
                }
            }
            if correctionEvaluation.decision == nil,
               correctionEvaluation.reason
                    != AutomaticCorrectionSelectionReason.supplementaryLexicon.rawValue,
               let spacingSelection = try EnglishContextualCorrectionPolicy
                    .missingSpaceCorrection(
                        typedWord: snapshot.currentWord,
                        correctionResponse: correctionResponse,
                        previousWord: snapshot.previousWords.first,
                        isSupplementaryWord: supplementaryLexicon.contains,
                        correctionResponseForWord: { word, previousWord in
                            try engine.predict(
                                typedWord: word,
                                previousWords: previousWord.map { [$0] } ?? [],
                                touches: [],
                                mode: .correction
                            )
                        },
                        analyze: { try engine.analyze(word: $0, previousWord: $1) }
                    ) {
                correctionEvaluation = CorrectionEvaluation(
                    decision: KeyboardAutomaticCorrectionDecision(
                        original: snapshot.currentWord,
                        replacement: Self.applyCase(
                            of: snapshot.currentWord,
                            to: spacingSelection.replacement
                        ),
                        probability: 1
                    ),
                    reason: AutomaticCorrectionSelectionReason.missingSpaceRecovery.rawValue,
                    selectedProbability: 1,
                    competingProbability: 0
                )
            }
            if correctionEvaluation.decision == nil,
               let rollingEvaluation = try Self.makeRollingEvaluation(
                    deferredWords: deferredWords,
                    currentWord: snapshot.currentWord,
                    currentResponse: correctionResponse,
                    currentProtectsLiteral: protectsLiteral,
                    snapshotPreviousWords: snapshot.previousWords,
                    engine: engine,
                    supplementaryLexicon: supplementaryLexicon
               ) {
                correctionEvaluation = rollingEvaluation
            }
            KeyboardTypingDiagnostics.log("correction_evaluation", fields: [
                "request_id": diagnosticRequestIdentifier,
                "original": snapshot.currentWord,
                "reason": correctionEvaluation.reason,
                "typed_word_valid": correctionResponse.typedWordIsValid,
                "action_probability": correctionResponse.automaticCorrectionProbability,
                "selected_probability": correctionEvaluation.selectedProbability,
                "competing_probability": correctionEvaluation.competingProbability,
                "replacement": correctionEvaluation.decision?.replacement ?? "none",
            ])
            return GeneratedState(
                currentWord: snapshot.currentWord,
                previousWords: snapshot.previousWords,
                choices: choices,
                correction: correctionEvaluation.decision,
                correctionResponse: correctionResponse,
                protectsLiteral: protectsLiteral
            )
        } catch {
            reportEngineFailure(error)
            let choices = snapshot.currentWord.isEmpty
                ? []
                : [KeyboardPredictionChoice(text: snapshot.currentWord, kind: .literal)]
            return GeneratedState(
                currentWord: snapshot.currentWord,
                previousWords: snapshot.previousWords,
                choices: choices,
                correction: nil,
                correctionResponse: nil,
                protectsLiteral: protectsLiteral
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

    private func alignedDeferredWords(
        with previousWordsNewestFirst: [String]
    ) -> [DeferredWord] {
        var matchedNewestFirst: [DeferredWord] = []
        let count = min(deferredWords.count, previousWordsNewestFirst.count)
        for offset in 0..<count {
            let deferred = deferredWords[deferredWords.count - offset - 1]
            guard deferred.original.caseInsensitiveCompare(
                previousWordsNewestFirst[offset]
            ) == .orderedSame else {
                break
            }
            matchedNewestFirst.append(deferred)
        }
        return Array(matchedNewestFirst.reversed())
    }

    private func retainDeferredResponse(from state: GeneratedState) -> Bool {
        guard let response = state.correctionResponse,
              let index = deferredWords.lastIndex(where: { deferred in
                  deferred.correctionResponse == nil
                      && deferred.original.caseInsensitiveCompare(state.currentWord)
                            == .orderedSame
                      && Self.wordsMatch(
                        deferred.previousWords,
                        state.previousWords
                      )
              }) else {
            return false
        }
        let existing = deferredWords[index]
        deferredWords[index] = DeferredWord(
            original: existing.original,
            previousWords: existing.previousWords,
            correctionResponse: response,
            protectsLiteral: existing.protectsLiteral || state.protectsLiteral
        )
        return true
    }

    private static func wordsMatch(_ left: [String], _ right: [String]) -> Bool {
        guard left.count == right.prefix(3).count else { return false }
        return zip(left, right).allSatisfy { words in
            words.0.caseInsensitiveCompare(words.1) == .orderedSame
        }
    }

    private static func makeCorrectionEvaluation(
        original: String,
        response: PredictionResponse,
        protectsLiteral: Bool,
        supplementaryLexicon: KeyboardSupplementaryLexicon
    ) -> CorrectionEvaluation {
        guard protectsLiteral == false else {
            return CorrectionEvaluation(
                decision: nil,
                reason: "literal_protected",
                selectedProbability: 0,
                competingProbability: 0
            )
        }
        if let replacement = supplementaryLexicon.replacement(for: original),
           replacement != original {
            return CorrectionEvaluation(
                decision: KeyboardAutomaticCorrectionDecision(
                    original: original,
                    replacement: replacement,
                    probability: 1
                ),
                reason: AutomaticCorrectionSelectionReason.supplementaryLexicon.rawValue,
                selectedProbability: 1,
                competingProbability: 0
            )
        }
        guard allowsAutomaticCorrectionCase(for: original) else {
            return CorrectionEvaluation(
                decision: nil,
                reason: "unsupported_case",
                selectedProbability: 0,
                competingProbability: 0
            )
        }
        guard supplementaryLexicon.contains(original) == false else {
            return CorrectionEvaluation(
                decision: nil,
                reason: AutomaticCorrectionSelectionReason.supplementaryLexicon.rawValue,
                selectedProbability: 0,
                competingProbability: 0
            )
        }
        if let replacement = EnglishAutomaticCorrectionPolicy.grammaticalReplacement(
            for: original
        ) {
            return CorrectionEvaluation(
                decision: KeyboardAutomaticCorrectionDecision(
                    original: original,
                    replacement: replacement,
                    probability: 1
                ),
                reason: AutomaticCorrectionSelectionReason.grammaticalReplacement.rawValue,
                selectedProbability: 1,
                competingProbability: 0
            )
        }
        guard response.typedWordIsValid == false else {
            return CorrectionEvaluation(
                decision: nil,
                reason: AutomaticCorrectionSelectionReason.typedWordValid.rawValue,
                selectedProbability: 0,
                competingProbability: 0
            )
        }
        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: original,
            response: response
        )
        guard let suggestion = selection.suggestion else {
            return CorrectionEvaluation(
                decision: nil,
                reason: selection.reason.rawValue,
                selectedProbability: 0,
                competingProbability: selection.competingProbability
            )
        }
        let replacement = applyCase(of: original, to: suggestion.word)
        guard replacement.caseInsensitiveCompare(original) != .orderedSame else {
            return CorrectionEvaluation(
                decision: nil,
                reason: "same_as_typed",
                selectedProbability: suggestion.rankProbability,
                competingProbability: selection.competingProbability
            )
        }
        return CorrectionEvaluation(
            decision: KeyboardAutomaticCorrectionDecision(
                original: original,
                replacement: replacement,
                probability: suggestion.rankProbability
            ),
            reason: selection.reason.rawValue,
            selectedProbability: suggestion.rankProbability,
            competingProbability: selection.competingProbability
        )
    }

    private static func makeRollingEvaluation(
        deferredWords: [DeferredWord],
        currentWord: String,
        currentResponse: PredictionResponse,
        currentProtectsLiteral: Bool,
        snapshotPreviousWords: [String],
        engine: EnglishPredictiveEngine,
        supplementaryLexicon: KeyboardSupplementaryLexicon
    ) throws -> CorrectionEvaluation? {
        guard deferredWords.isEmpty == false else { return nil }
        let rollingTokens = deferredWords.map {
            RollingCorrectionToken(
                original: $0.original,
                correctionResponse: $0.correctionResponse,
                protectsLiteral: $0.protectsLiteral
            )
        } + [RollingCorrectionToken(
            original: currentWord,
            correctionResponse: currentResponse,
            protectsLiteral: currentProtectsLiteral
        )]
        let precedingWords = Array(
            snapshotPreviousWords.dropFirst(deferredWords.count)
        )
        guard let selection = try EnglishRollingCorrectionPolicy.select(
                tokens: rollingTokens,
                precedingWords: precedingWords,
                isProtectedWord: supplementaryLexicon.contains,
                analyze: { try engine.analyze(word: $0, previousWords: $1) }
        ) else {
            return nil
        }
        guard let firstChangedIndex = selection.changedIndices.first else {
            return nil
        }
        let originalWords = rollingTokens.map(\.original)
        let originalSuffix = originalWords[firstChangedIndex...].joined(separator: " ")
        let replacementSuffix = zip(
            originalWords[firstChangedIndex...],
            selection.replacementWords[firstChangedIndex...]
        ).map { original, replacement in
            applyCase(of: original, to: replacement)
        }.joined(separator: " ")
        let probability = 1 - exp(-selection.languageScoreImprovement)
        return CorrectionEvaluation(
            decision: KeyboardAutomaticCorrectionDecision(
                original: originalSuffix,
                replacement: replacementSuffix,
                probability: probability
            ),
            reason: AutomaticCorrectionSelectionReason.rollingContext.rawValue,
            selectedProbability: probability,
            competingProbability: 0
        )
    }

    private static func diagnosticMilliseconds(since start: TimeInterval) -> Double {
        ((ProcessInfo.processInfo.systemUptime - start) * 100_000).rounded() / 100
    }

    @discardableResult
    private func advanceGeneration() -> Int {
        generationLock.lock()
        defer { generationLock.unlock() }
        generation += 1
        return generation
    }

    private func currentGeneration() -> Int {
        generationLock.lock()
        defer { generationLock.unlock() }
        return generation
    }

    private static func allowsAutomaticCorrectionCase(for word: String) -> Bool {
        if word == word.lowercased() { return true }
        guard word.first?.isUppercase == true else { return false }
        return String(word.dropFirst()) == String(word.dropFirst()).lowercased()
    }

    private static func makeChoices(
        literal: String,
        completionSuggestions: [PredictiveSuggestion],
        correctionResponse: PredictionResponse,
        supplementaryLexicon: KeyboardSupplementaryLexicon,
        userDictionarySuggestion: String?
    ) -> [KeyboardPredictionChoice] {
        var observed = Set([literal.lowercased()])
        var candidates: [KeyboardPredictionChoice] = []
        var userDictionaryChoice: KeyboardPredictionChoice?

        if let userDictionarySuggestion,
           userDictionarySuggestion != literal {
            let choice = KeyboardPredictionChoice(
                text: userDictionarySuggestion,
                kind: .correction
            )
            userDictionaryChoice = choice
            candidates.append(choice)
            observed.insert(userDictionarySuggestion.lowercased())
        }

        if let replacement = supplementaryLexicon.replacement(for: literal),
           replacement != literal {
            candidates.append(
                KeyboardPredictionChoice(text: replacement, kind: .correction)
            )
            observed.insert(replacement.lowercased())
        }

        if let grammaticalReplacement = EnglishAutomaticCorrectionPolicy
            .grammaticalReplacement(for: literal) {
            candidates.append(
                KeyboardPredictionChoice(
                    text: grammaticalReplacement,
                    kind: .correction
                )
            )
        }

        let policySelection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: literal,
            response: correctionResponse
        )
        if correctionResponse.typedWordIsValid == false,
           literal.count >= 2,
           let correction = policySelection.suggestion ?? correctionResponse.suggestions.first {
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
        if let userDictionaryChoice {
            var orderedChoices = [literalChoice, userDictionaryChoice]
            if let trailingChoice = candidates.first(where: { $0 != userDictionaryChoice }) {
                orderedChoices.append(trailingChoice)
            }
            return orderedChoices
        }
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
            .suffix(8)
            .reversed()
            .map(String.init)
        return TextSnapshot(currentWord: currentWord, previousWords: previousWords)
    }
}
