import Foundation
import CoreML

extension ParakeetCoreMLBackend {
    func decodeChunk(
        audioFrames: [Float],
        params: ParakeetParams,
        requestID: UUID,
        startFrame: Int
    ) throws -> DecodedChunk {
        try throwIfCancelled(requestID)

        let actualFrameCount = min(audioFrames.count, Constants.chunkFrameCount)
        let paddedFrames = paddedAudioFrames(from: audioFrames, frameCount: actualFrameCount)

        let preprocessorFeatures = try preprocessorModel.prediction(from: audioFeatureProvider(audioFrames: paddedFrames, frameCount: actualFrameCount))
        let mel = try requireMultiArray(named: "mel", from: preprocessorFeatures)
        let melLengthArray = try requireMultiArray(named: "mel_length", from: preprocessorFeatures)

        let encoderFeatures = try encoderModel.prediction(
            from: MLDictionaryFeatureProvider(
                dictionary: [
                    "mel": MLFeatureValue(multiArray: mel),
                    "mel_length": MLFeatureValue(multiArray: melLengthArray),
                ]
            )
        )

        let encoderOutput = try requireMultiArray(named: "encoder", from: encoderFeatures)
        let encoderLengthArray = try requireMultiArray(named: "encoder_length", from: encoderFeatures)
        let encoderLength = max(0, min(Constants.encoderFrameCapacity, Int(int32Value(in: encoderLengthArray, at: [0]))))
        if encoderLength == 0 {
            return DecodedChunk(
                text: "",
                emittedTokens: [],
                detectedLanguageCode: nil,
                detectedLanguageName: nil,
                confidence: nil,
                noSpeechProbability: 1,
                relativeStartTimeMilliseconds: 0,
                relativeEndTimeMilliseconds: milliseconds(forFrameCount: actualFrameCount)
            )
        }

        let encoderFrames = try EncoderFrameAccessor(array: encoderOutput, validFrameCount: encoderLength)
        let encoderStepInput = try makeFloat32Array(shape: [1, Constants.encoderChannelCount, 1])
        let decoderStepInput = try makeFloat32Array(shape: [1, Constants.decoderHiddenSize, 1])
        var decoderStep = try initialDecoderStep()
        decoderStep = try applyInitialPromptIfNeeded(params.initialPrompt, to: decoderStep)
        var emittedTokens: [EmittedToken] = []
        emittedTokens.reserveCapacity(min(encoderFrames.frameCount * 2, Constants.maxTokenCountPerChunk))

        var detectedLanguageCode: String?
        var noSpeechProbability: Float?
        var confidenceTotal: Float = 0
        var confidenceCount = 0
        var timeIndex = 0
        var firstTextTimeIndex: Int?
        var lastTextEndTimeIndex: Int?
        var firstLexicalTextTimeIndex: Int?
        var lastLexicalTextEndTimeIndex: Int?
        var lastEmissionTimeIndex = -1
        var emissionsAtCurrentTimeIndex = 0
        var loggedDecisions = 0

        while timeIndex < encoderFrames.frameCount && emittedTokens.count < Constants.maxTokenCountPerChunk {
            try throwIfCancelled(requestID)

            let currentTimeIndex = timeIndex
            encoderFrames.copyFrame(at: currentTimeIndex, into: encoderStepInput)
            try normalizeDecoderProjection(decoderStep.output, into: decoderStepInput)
            let decision = try runJointDecision(
                encoderStep: encoderStepInput,
                decoderStep: decoderStepInput
            )
            var duration = try mappedDuration(for: decision.duration)
            let isBlank = decision.tokenID == blankTokenID

            if loggedDecisions < Constants.debugDecisionLogLimit {
                debugLog(
                    "decision[\(loggedDecisions)] time=\(currentTimeIndex) token=\(decision.tokenID) piece=\(vocabulary.token(for: decision.tokenID) ?? "<nil>") duration=\(duration) prob=\(decision.tokenProbability)"
                )
                loggedDecisions += 1
            }

            if isBlank && duration == 0 {
                duration = 1
            }
            if !isBlank && duration == 0 && currentTimeIndex == lastEmissionTimeIndex && emissionsAtCurrentTimeIndex >= 1 {
                duration = 1
            }

            switch vocabulary.kind(for: decision.tokenID) {
            case let .language(languageCode)?:
                if detectedLanguageCode == nil {
                    detectedLanguageCode = languageCode
                }
                if currentTimeIndex == lastEmissionTimeIndex {
                    emissionsAtCurrentTimeIndex += 1
                } else {
                    lastEmissionTimeIndex = currentTimeIndex
                    emissionsAtCurrentTimeIndex = 1
                }
            case .control("nospeech")?:
                noSpeechProbability = max(noSpeechProbability ?? 0, decision.tokenProbability)
                if currentTimeIndex == lastEmissionTimeIndex {
                    emissionsAtCurrentTimeIndex += 1
                } else {
                    lastEmissionTimeIndex = currentTimeIndex
                    emissionsAtCurrentTimeIndex = 1
                }
            case .control("endoftext")?:
                timeIndex = encoderFrames.frameCount
                continue
            case .text?:
                let tokenStartFrame = startFrame + Self.relativeFrameIndex(
                    forEncoderTimeIndex: currentTimeIndex,
                    encoderFrameCount: encoderFrames.frameCount,
                    actualFrameCount: actualFrameCount
                )
                let tokenEndFrame = startFrame + Self.relativeFrameIndex(
                    forEncoderTimeIndex: currentTimeIndex + max(duration, 1),
                    encoderFrameCount: encoderFrames.frameCount,
                    actualFrameCount: actualFrameCount
                )
                emittedTokens.append(
                    EmittedToken(
                        tokenID: decision.tokenID,
                        confidence: decision.tokenProbability,
                        startFrame: tokenStartFrame,
                        endFrame: max(tokenStartFrame, tokenEndFrame)
                    )
                )
                confidenceTotal += decision.tokenProbability
                confidenceCount += 1
                if firstTextTimeIndex == nil {
                    firstTextTimeIndex = currentTimeIndex
                }
                lastTextEndTimeIndex = max(
                    lastTextEndTimeIndex ?? 0,
                    currentTimeIndex + max(duration, 1)
                )
                if vocabulary.tokenHasLexicalContent(for: decision.tokenID) {
                    if firstLexicalTextTimeIndex == nil {
                        firstLexicalTextTimeIndex = currentTimeIndex
                    }
                    lastLexicalTextEndTimeIndex = max(
                        lastLexicalTextEndTimeIndex ?? 0,
                        currentTimeIndex + max(duration, 1)
                    )
                }
                if currentTimeIndex == lastEmissionTimeIndex {
                    emissionsAtCurrentTimeIndex += 1
                } else {
                    lastEmissionTimeIndex = currentTimeIndex
                    emissionsAtCurrentTimeIndex = 1
                }
            case .control?:
                if currentTimeIndex == lastEmissionTimeIndex {
                    emissionsAtCurrentTimeIndex += 1
                } else {
                    lastEmissionTimeIndex = currentTimeIndex
                    emissionsAtCurrentTimeIndex = 1
                }
            case nil:
                break
            }

            if decision.tokenID != blankTokenID && decision.tokenID != Constants.endOfTextTokenID {
                decoderStep = try runDecoder(targetID: decision.tokenID, state: decoderStep.state)
            }

            if emissionsAtCurrentTimeIndex >= Constants.maxSymbolsPerTimeStep {
                timeIndex = min(encoderFrames.frameCount, currentTimeIndex + 1)
                emissionsAtCurrentTimeIndex = 0
                lastEmissionTimeIndex = -1
                continue
            }

            timeIndex = min(encoderFrames.frameCount, currentTimeIndex + duration)
        }

        let finalText = vocabulary.decodedText(from: emittedTokens.map(\.tokenID))
        let languageName = detectedLanguageCode.flatMap { vocabulary.languageName(for: $0) }
        let averageConfidence = confidenceCount > 0 ? confidenceTotal / Float(confidenceCount) : nil
        let textTiming = Self.relativeTextTiming(
            firstTextTimeIndex: firstLexicalTextTimeIndex ?? firstTextTimeIndex,
            lastTextEndTimeIndex: lastLexicalTextEndTimeIndex ?? lastTextEndTimeIndex,
            fallbackEndTimeIndex: timeIndex,
            encoderFrameCount: encoderFrames.frameCount,
            actualFrameCount: actualFrameCount
        )

        return DecodedChunk(
            text: finalText,
            emittedTokens: emittedTokens,
            detectedLanguageCode: detectedLanguageCode,
            detectedLanguageName: languageName,
            confidence: averageConfidence,
            noSpeechProbability: noSpeechProbability,
            relativeStartTimeMilliseconds: textTiming.startMilliseconds,
            relativeEndTimeMilliseconds: textTiming.endMilliseconds
        )
    }

    func applyInitialPromptIfNeeded(_ prompt: String, to decoderStep: DecoderStep) throws -> DecoderStep {
        let promptTokenIDs = vocabulary.promptTokenIDs(from: prompt)
        guard !promptTokenIDs.isEmpty else { return decoderStep }

        var primedDecoderStep = decoderStep
        if let startOfContextTokenID = vocabulary.tokenID(forExactToken: "<|startofcontext|>") {
            primedDecoderStep = try runDecoder(targetID: startOfContextTokenID, state: primedDecoderStep.state)
        }

        for tokenID in promptTokenIDs {
            primedDecoderStep = try runDecoder(targetID: tokenID, state: primedDecoderStep.state)
        }

        debugLog("Applied prompt hint with \(promptTokenIDs.count) tokens")
        return primedDecoderStep
    }

    func initialDecoderStep() throws -> DecoderStep {
        let hiddenState = try makeFloat32Array(shape: [Constants.decoderLayerCount, 1, Constants.decoderHiddenSize])
        let cellState = try makeFloat32Array(shape: [Constants.decoderLayerCount, 1, Constants.decoderHiddenSize])
        let zeroState = DecoderState(
            hidden: hiddenState,
            cell: cellState
        )

        debugLog("Initializing decoder with RNNT blank token \(blankTokenID)")

        return try runDecoder(
            targetID: blankTokenID,
            state: zeroState
        )
    }
}
