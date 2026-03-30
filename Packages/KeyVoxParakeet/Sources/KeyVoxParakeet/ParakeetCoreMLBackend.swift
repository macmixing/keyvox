import Foundation
import CoreML

internal final class ParakeetCoreMLBackend: ParakeetRuntimeBackend {
    private enum Constants {
        static let sampleRate: Double = 16_000
        static let chunkFrameCount = 240_000
        static let encoderChannelCount = 1_024
        static let encoderFrameCapacity = 188
        static let decoderLayerCount = 2
        static let decoderHiddenSize = 640
        static let maxSymbolsPerTimeStep = 10
        static let maxTokenCountPerChunk = 4_096
        static let debugDecisionLogLimit = 24
        static let durationBins = [0, 1, 2, 3, 4]
        static let preprocessorDirectoryName = "Preprocessor.mlmodelc"
        static let encoderDirectoryName = "Encoder.mlmodelc"
        static let decoderDirectoryName = "Decoder.mlmodelc"
        static let canonicalJointDirectoryName = "JointDecision.mlmodelc"
        static let jointDirectoryName = "JointDecisionv2.mlmodelc"
        static let noSpeechTokenID: Int32 = 1
        static let endOfTextTokenID: Int32 = 3
    }

    private struct EncoderFrameAccessor {
        let array: MLMultiArray
        let hiddenSize: Int
        let frameCount: Int
        let hiddenStride: Int
        let timeStride: Int
        let timeBaseOffset: Int

        init(array: MLMultiArray, validFrameCount: Int) throws {
            let shape = array.shape.map(\.intValue)
            guard shape.count == 3, shape[0] == 1 else {
                throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_encoder_shape")
            }

            let axis1MatchesHidden = shape[1] == Constants.encoderChannelCount
            let axis2MatchesHidden = shape[2] == Constants.encoderChannelCount
            guard axis1MatchesHidden || axis2MatchesHidden else {
                throw ParakeetError.transcriptionFailed(code: -1, message: "encoder_hidden_size_mismatch")
            }

            let hiddenAxis = axis1MatchesHidden ? 1 : 2
            let timeAxis = axis1MatchesHidden ? 2 : 1
            let strides = array.strides.map(\.intValue)
            let availableFrames = shape[timeAxis]

            self.array = array
            self.hiddenSize = Constants.encoderChannelCount
            self.frameCount = min(validFrameCount, availableFrames)
            self.hiddenStride = strides[hiddenAxis]
            self.timeStride = strides[timeAxis]
            self.timeBaseOffset = timeStride >= 0 ? 0 : (availableFrames - 1) * timeStride
        }

        func copyFrame(at frameIndex: Int, into destination: MLMultiArray) {
            let sourcePointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
            let destinationHiddenStride = destination.strides[1].intValue
            let sourceBaseIndex = timeBaseOffset + (frameIndex * timeStride)

            for hiddenIndex in 0..<hiddenSize {
                destinationPointer[hiddenIndex * destinationHiddenStride] =
                    sourcePointer[sourceBaseIndex + (hiddenIndex * hiddenStride)]
            }
        }
    }

    private struct DecoderState {
        let hidden: MLMultiArray
        let cell: MLMultiArray
    }

    private struct DecoderStep {
        let output: MLMultiArray
        let state: DecoderState
    }

    private struct JointDecision {
        let tokenID: Int32
        let tokenProbability: Float
        let duration: Int32
    }

    private struct DecodedChunk {
        let text: String
        let detectedLanguageCode: String?
        let detectedLanguageName: String?
        let confidence: Float?
        let noSpeechProbability: Float?
        let relativeEndTimeMilliseconds: Int
    }

    private let preprocessorModel: MLModel
    private let encoderModel: MLModel
    private let decoderModel: MLModel
    private let jointModel: MLModel
    private let vocabulary: ParakeetVocabulary
    private let blankTokenID: Int32
    private let lock = NSLock()
    private var activeRequestID = UUID()

    init(modelDirectoryURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: modelDirectoryURL.path) else {
            throw ParakeetError.modelNotFound
        }

        let preprocessorDirectoryURL = modelDirectoryURL.appendingPathComponent(Constants.preprocessorDirectoryName, isDirectory: true)
        let encoderDirectoryURL = modelDirectoryURL.appendingPathComponent(Constants.encoderDirectoryName, isDirectory: true)
        let decoderDirectoryURL = modelDirectoryURL.appendingPathComponent(Constants.decoderDirectoryName, isDirectory: true)
        let jointDirectoryURL = Self.preferredJointDirectoryURL(in: modelDirectoryURL, fileManager: fileManager)

        let requiredDirectoryURLs = [
            preprocessorDirectoryURL,
            encoderDirectoryURL,
            decoderDirectoryURL,
            jointDirectoryURL,
        ]

        for directoryURL in requiredDirectoryURLs where !fileManager.fileExists(atPath: directoryURL.path) {
            throw ParakeetError.initializationFailed
        }

        let preprocessorConfiguration = MLModelConfiguration()
        preprocessorConfiguration.computeUnits = .cpuOnly

        let inferenceConfiguration = MLModelConfiguration()
        inferenceConfiguration.computeUnits = .cpuAndNeuralEngine

        do {
            self.preprocessorModel = try MLModel(contentsOf: preprocessorDirectoryURL, configuration: preprocessorConfiguration)
            self.encoderModel = try MLModel(contentsOf: encoderDirectoryURL, configuration: inferenceConfiguration)
            self.decoderModel = try MLModel(contentsOf: decoderDirectoryURL, configuration: inferenceConfiguration)
            self.jointModel = try MLModel(contentsOf: jointDirectoryURL, configuration: inferenceConfiguration)
            self.vocabulary = try ParakeetVocabulary(modelDirectoryURL: modelDirectoryURL)
            self.blankTokenID = vocabulary.tokenCount
            debugLog("loaded_joint=\(jointDirectoryURL.lastPathComponent)")
        } catch let error as ParakeetError {
            throw error
        } catch {
            throw ParakeetError.initializationFailed
        }
    }

    func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult {
        let requestID = beginRequest()
        var segments: [ParakeetSegment] = []
        var detectedLanguageCode: String?
        var detectedLanguageName: String?

        var frameOffset = 0
        while frameOffset < audioFrames.count {
            try throwIfCancelled(requestID)

            let chunkUpperBound = min(frameOffset + Constants.chunkFrameCount, audioFrames.count)
            let chunkFrames = Array(audioFrames[frameOffset..<chunkUpperBound])
            let decodedChunk = try decodeChunk(audioFrames: chunkFrames, params: params, requestID: requestID)

            if detectedLanguageCode == nil {
                detectedLanguageCode = decodedChunk.detectedLanguageCode
                detectedLanguageName = decodedChunk.detectedLanguageName
            }

            if !decodedChunk.text.isEmpty {
                let segmentStart = milliseconds(forFrameIndex: frameOffset)
                let chunkEnd = milliseconds(forFrameIndex: chunkUpperBound)
                let segmentEnd = min(chunkEnd, segmentStart + max(decodedChunk.relativeEndTimeMilliseconds, 0))

                segments.append(
                    ParakeetSegment(
                        startTime: segmentStart,
                        endTime: max(segmentStart, segmentEnd),
                        text: decodedChunk.text,
                        confidence: decodedChunk.confidence,
                        noSpeechProbability: decodedChunk.noSpeechProbability
                    )
                )
            }

            frameOffset = chunkUpperBound
        }

        return ParakeetTranscriptionResult(
            segments: segments,
            detectedLanguageCode: detectedLanguageCode,
            detectedLanguageName: detectedLanguageName
        )
    }

    func cancelCurrentTranscription() {
        lock.lock()
        activeRequestID = UUID()
        lock.unlock()
    }

    func unload() {
        cancelCurrentTranscription()
    }

    private func beginRequest() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let requestID = UUID()
        activeRequestID = requestID
        return requestID
    }

    private func isCurrentRequest(_ requestID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeRequestID == requestID
    }

    private func throwIfCancelled(_ requestID: UUID) throws {
        if Task.isCancelled || !isCurrentRequest(requestID) {
            throw ParakeetError.cancelled
        }
    }

    private func decodeChunk(
        audioFrames: [Float],
        params: ParakeetParams,
        requestID: UUID
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
                detectedLanguageCode: nil,
                detectedLanguageName: nil,
                confidence: nil,
                noSpeechProbability: 1,
                relativeEndTimeMilliseconds: milliseconds(forFrameCount: actualFrameCount)
            )
        }

        let encoderFrames = try EncoderFrameAccessor(array: encoderOutput, validFrameCount: encoderLength)
        let encoderStepInput = try makeFloat32Array(shape: [1, Constants.encoderChannelCount, 1])
        let decoderStepInput = try makeFloat32Array(shape: [1, Constants.decoderHiddenSize, 1])
        var decoderStep = try initialDecoderStep()
        decoderStep = try applyInitialPromptIfNeeded(params.initialPrompt, to: decoderStep)
        var emittedTokenIDs: [Int32] = []
        emittedTokenIDs.reserveCapacity(min(encoderFrames.frameCount * 2, Constants.maxTokenCountPerChunk))

        var detectedLanguageCode: String?
        var noSpeechProbability: Float?
        var confidenceTotal: Float = 0
        var confidenceCount = 0
        var timeIndex = 0
        var lastEmissionTimeIndex = -1
        var emissionsAtCurrentTimeIndex = 0
        var loggedDecisions = 0

        while timeIndex < encoderFrames.frameCount && emittedTokenIDs.count < Constants.maxTokenCountPerChunk {
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
            case .control("nospeech")?:
                noSpeechProbability = max(noSpeechProbability ?? 0, decision.tokenProbability)
            case .control("endoftext")?:
                timeIndex = encoderFrames.frameCount
                continue
            case .text?:
                emittedTokenIDs.append(decision.tokenID)
                confidenceTotal += decision.tokenProbability
                confidenceCount += 1
                if currentTimeIndex == lastEmissionTimeIndex {
                    emissionsAtCurrentTimeIndex += 1
                } else {
                    lastEmissionTimeIndex = currentTimeIndex
                    emissionsAtCurrentTimeIndex = 1
                }
            case .control?, nil:
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

        let finalText = vocabulary.decodedText(from: emittedTokenIDs)
        let languageName = detectedLanguageCode.flatMap { vocabulary.languageName(for: $0) }
        let averageConfidence = confidenceCount > 0 ? confidenceTotal / Float(confidenceCount) : nil

        return DecodedChunk(
            text: finalText,
            detectedLanguageCode: detectedLanguageCode,
            detectedLanguageName: languageName,
            confidence: averageConfidence,
            noSpeechProbability: noSpeechProbability,
            relativeEndTimeMilliseconds: Int((Double(timeIndex) / Double(max(encoderFrames.frameCount, 1))) * Double(milliseconds(forFrameCount: actualFrameCount)))
        )
    }

    private func applyInitialPromptIfNeeded(_ prompt: String, to decoderStep: DecoderStep) throws -> DecoderStep {
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

    private func paddedAudioFrames(from audioFrames: [Float], frameCount: Int) -> [Float] {
        if frameCount == Constants.chunkFrameCount {
            return audioFrames
        }

        var paddedFrames = Array(audioFrames.prefix(frameCount))
        paddedFrames.reserveCapacity(Constants.chunkFrameCount)
        paddedFrames.append(contentsOf: repeatElement(0, count: Constants.chunkFrameCount - frameCount))
        return paddedFrames
    }

    private func audioFeatureProvider(audioFrames: [Float], frameCount: Int) throws -> MLDictionaryFeatureProvider {
        let audioSignal = try makeFloat32Array(shape: [1, Constants.chunkFrameCount])
        fill(audioSignal, with: audioFrames)

        let audioLength = try makeInt32Array(shape: [1])
        set(Int32(frameCount), in: audioLength, at: [0])

        return try MLDictionaryFeatureProvider(
            dictionary: [
                "audio_signal": MLFeatureValue(multiArray: audioSignal),
                "audio_length": MLFeatureValue(multiArray: audioLength),
            ]
        )
    }

    private func initialDecoderStep() throws -> DecoderStep {
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

    private func runDecoder(targetID: Int32, state: DecoderState) throws -> DecoderStep {
        let targets = try makeInt32Array(shape: [1, 1])
        set(targetID, in: targets, at: [0, 0])

        let targetLength = try makeInt32Array(shape: [1])
        set(Int32(1), in: targetLength, at: [0])

        let features = try decoderModel.prediction(
            from: MLDictionaryFeatureProvider(
                dictionary: [
                    "targets": MLFeatureValue(multiArray: targets),
                    "target_length": MLFeatureValue(multiArray: targetLength),
                    "h_in": MLFeatureValue(multiArray: state.hidden),
                    "c_in": MLFeatureValue(multiArray: state.cell),
                ]
            )
        )

        return DecoderStep(
            output: try requireMultiArray(named: "decoder", from: features),
            state: DecoderState(
                hidden: try requireMultiArray(named: "h_out", from: features),
                cell: try requireMultiArray(named: "c_out", from: features)
            )
        )
    }

    private func runJointDecision(encoderStep: MLMultiArray, decoderStep: MLMultiArray) throws -> JointDecision {
        let features = try jointModel.prediction(
            from: MLDictionaryFeatureProvider(
                dictionary: [
                    "encoder_step": MLFeatureValue(multiArray: encoderStep),
                    "decoder_step": MLFeatureValue(multiArray: decoderStep),
                ]
            )
        )

        let tokenID = try requireMultiArray(named: "token_id", from: features)
        let tokenProbability = try requireMultiArray(named: "token_prob", from: features)
        let duration = try requireMultiArray(named: "duration", from: features)

        return JointDecision(
            tokenID: int32Value(in: tokenID, at: [0, 0, 0]),
            tokenProbability: float32Value(in: tokenProbability, at: [0, 0, 0]),
            duration: int32Value(in: duration, at: [0, 0, 0])
        )
    }

    private func normalizeDecoderProjection(_ projection: MLMultiArray, into destination: MLMultiArray) throws {
        let shape = projection.shape.map(\.intValue)
        guard shape.count == 3, shape[0] == 1 else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_decoder_shape")
        }

        let hiddenAxis: Int
        if shape[2] == Constants.decoderHiddenSize {
            hiddenAxis = 2
        } else if shape[1] == Constants.decoderHiddenSize {
            hiddenAxis = 1
        } else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "decoder_hidden_size_mismatch")
        }

        let timeAxis = hiddenAxis == 2 ? 1 : 2
        guard shape[timeAxis] == 1 else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_decoder_time_axis")
        }

        let projectionStrides = projection.strides.map(\.intValue)
        let destinationStride = destination.strides[1].intValue
        let sourceBase = projection.dataPointer.bindMemory(to: Float.self, capacity: projection.count)
        let destinationBase = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let hiddenStride = projectionStrides[hiddenAxis]

        for hiddenIndex in 0..<Constants.decoderHiddenSize {
            destinationBase[hiddenIndex * destinationStride] = sourceBase[hiddenIndex * hiddenStride]
        }
    }

    private func requireMultiArray(named featureName: String, from provider: MLFeatureProvider) throws -> MLMultiArray {
        guard let value = provider.featureValue(for: featureName)?.multiArrayValue else {
            throw ParakeetError.transcriptionFailed(code: -1, message: featureName)
        }
        return value
    }

    private func makeFloat32Array(shape: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .float32)
        zero(array)
        return array
    }

    private func makeInt32Array(shape: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .int32)
        zero(array)
        return array
    }

    private func fill(_ array: MLMultiArray, with values: [Float]) {
        for (index, value) in values.enumerated() {
            set(value, in: array, atLinearIndex: index)
        }
    }

    private func offset(in array: MLMultiArray, indices: [Int]) -> Int {
        zip(indices, array.strides).reduce(0) { partialResult, pair in
            partialResult + (pair.0 * pair.1.intValue)
        }
    }

    private func set(_ value: Float, in array: MLMultiArray, at indices: [Int]) {
        set(value, in: array, atLinearIndex: offset(in: array, indices: indices))
    }

    private func set(_ value: Float, in array: MLMultiArray, atLinearIndex index: Int) {
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        pointer[index] = value
    }

    private func set(_ value: Int32, in array: MLMultiArray, at indices: [Int]) {
        let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
        pointer[offset(in: array, indices: indices)] = value
    }

    private func zero(_ array: MLMultiArray) {
        switch array.dataType {
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            pointer.initialize(repeating: 0, count: array.count)
        case .int32:
            let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
            pointer.initialize(repeating: 0, count: array.count)
        default:
            break
        }
    }

    private func float32Value(in array: MLMultiArray, at indices: [Int]) -> Float {
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        return pointer[offset(in: array, indices: indices)]
    }

    private func int32Value(in array: MLMultiArray, at indices: [Int]) -> Int32 {
        let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
        return pointer[offset(in: array, indices: indices)]
    }

    private func milliseconds(forFrameIndex frameIndex: Int) -> Int {
        Int((Double(frameIndex) / Constants.sampleRate) * 1000)
    }

    private func milliseconds(forFrameCount frameCount: Int) -> Int {
        milliseconds(forFrameIndex: frameCount)
    }

    private func mappedDuration(for durationBin: Int32) throws -> Int {
        let index = Int(durationBin)
        guard Constants.durationBins.indices.contains(index) else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_duration_bin")
        }
        return Constants.durationBins[index]
    }

    private static func preferredJointDirectoryURL(in modelDirectoryURL: URL, fileManager: FileManager) -> URL {
        let canonicalURL = modelDirectoryURL.appendingPathComponent(Constants.canonicalJointDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: canonicalURL.path) {
            return canonicalURL
        }
        return modelDirectoryURL.appendingPathComponent(Constants.jointDirectoryName, isDirectory: true)
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[ParakeetCoreML] \(message)")
#endif
    }
}
