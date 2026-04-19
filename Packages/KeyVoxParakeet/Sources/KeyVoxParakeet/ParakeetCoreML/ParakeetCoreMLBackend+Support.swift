import Foundation
import CoreML

extension ParakeetCoreMLBackend {
    enum Constants {
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

    struct EncoderFrameAccessor {
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

    struct DecoderState {
        let hidden: MLMultiArray
        let cell: MLMultiArray
    }

    struct DecoderStep {
        let output: MLMultiArray
        let state: DecoderState
    }

    struct JointDecision {
        let tokenID: Int32
        let tokenProbability: Float
        let duration: Int32
    }

    struct DecodedChunk {
        let text: String
        let emittedTokens: [EmittedToken]
        let detectedLanguageCode: String?
        let detectedLanguageName: String?
        let confidence: Float?
        let noSpeechProbability: Float?
        let relativeStartTimeMilliseconds: Int
        let relativeEndTimeMilliseconds: Int
    }

    struct EmittedToken: Equatable {
        let tokenID: Int32
        let confidence: Float
        let startFrame: Int
        let endFrame: Int
    }

    struct DecodeWindow: Equatable {
        let startFrame: Int
        let endFrame: Int
        let usesTailContext: Bool
    }

    struct RelativeTextTiming: Equatable {
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    func paddedAudioFrames(from audioFrames: [Float], frameCount: Int) -> [Float] {
        if frameCount == Constants.chunkFrameCount {
            return audioFrames
        }

        var paddedFrames = Array(audioFrames.prefix(frameCount))
        paddedFrames.reserveCapacity(Constants.chunkFrameCount)
        paddedFrames.append(contentsOf: repeatElement(0, count: Constants.chunkFrameCount - frameCount))
        return paddedFrames
    }

    func audioFeatureProvider(audioFrames: [Float], frameCount: Int) throws -> MLDictionaryFeatureProvider {
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

    func milliseconds(forFrameIndex frameIndex: Int) -> Int {
        Int((Double(frameIndex) / Constants.sampleRate) * 1000)
    }

    func milliseconds(forFrameCount frameCount: Int) -> Int {
        milliseconds(forFrameIndex: frameCount)
    }

    static func relativeMilliseconds(
        forEncoderTimeIndex timeIndex: Int,
        encoderFrameCount: Int,
        actualFrameCount: Int
    ) -> Int {
        let clampedTimeIndex = max(0, min(timeIndex, encoderFrameCount))
        return Int(
            (Double(clampedTimeIndex) / Double(max(encoderFrameCount, 1))) *
            ((Double(actualFrameCount) / Constants.sampleRate) * 1000)
        )
    }

    static func relativeFrameIndex(
        forEncoderTimeIndex timeIndex: Int,
        encoderFrameCount: Int,
        actualFrameCount: Int
    ) -> Int {
        let clampedTimeIndex = max(0, min(timeIndex, encoderFrameCount))
        return Int(
            (Double(clampedTimeIndex) / Double(max(encoderFrameCount, 1))) *
            Double(actualFrameCount)
        )
    }

    static func relativeTextTiming(
        firstTextTimeIndex: Int?,
        lastTextEndTimeIndex: Int?,
        fallbackEndTimeIndex: Int,
        encoderFrameCount: Int,
        actualFrameCount: Int
    ) -> RelativeTextTiming {
        let fallbackEndMilliseconds = relativeMilliseconds(
            forEncoderTimeIndex: fallbackEndTimeIndex,
            encoderFrameCount: encoderFrameCount,
            actualFrameCount: actualFrameCount
        )

        guard let firstTextTimeIndex, let lastTextEndTimeIndex else {
            return RelativeTextTiming(
                startMilliseconds: 0,
                endMilliseconds: fallbackEndMilliseconds
            )
        }

        let startMilliseconds = relativeMilliseconds(
            forEncoderTimeIndex: firstTextTimeIndex,
            encoderFrameCount: encoderFrameCount,
            actualFrameCount: actualFrameCount
        )
        let endMilliseconds = relativeMilliseconds(
            forEncoderTimeIndex: max(firstTextTimeIndex, lastTextEndTimeIndex),
            encoderFrameCount: encoderFrameCount,
            actualFrameCount: actualFrameCount
        )

        return RelativeTextTiming(
            startMilliseconds: startMilliseconds,
            endMilliseconds: max(startMilliseconds, endMilliseconds)
        )
    }

    static func decodeWindows(forFrameCount frameCount: Int) -> [DecodeWindow] {
        guard frameCount > 0 else { return [] }

        var windows: [DecodeWindow] = []
        var frameOffset = 0
        while frameOffset < frameCount {
            let upperBound = min(frameOffset + Constants.chunkFrameCount, frameCount)
            windows.append(
                DecodeWindow(
                    startFrame: frameOffset,
                    endFrame: upperBound,
                    usesTailContext: false
                )
            )
            frameOffset = upperBound
        }

        let hasFinalRemainder = frameCount > Constants.chunkFrameCount &&
            frameCount % Constants.chunkFrameCount != 0
        if hasFinalRemainder {
            let tailStartFrame = max(0, frameCount - Constants.chunkFrameCount)
            let tailWindow = DecodeWindow(
                startFrame: tailStartFrame,
                endFrame: frameCount,
                usesTailContext: true
            )
            if !windows.contains(tailWindow) {
                windows.append(tailWindow)
            }
        }

        return windows
    }

    static func mergedTokenIDs(_ accumulated: [Int32], appending next: [Int32]) -> [Int32] {
        guard !accumulated.isEmpty else { return next }
        guard !next.isEmpty else { return accumulated }

        var overlapCount = min(accumulated.count, next.count)
        while overlapCount > 0 {
            if Array(accumulated.suffix(overlapCount)) == Array(next.prefix(overlapCount)) {
                return accumulated + next.dropFirst(overlapCount)
            }
            overlapCount -= 1
        }

        return accumulated + next
    }

    static func mergedTokens(
        _ accumulated: [EmittedToken],
        appending next: [EmittedToken],
        usesTailContext: Bool
    ) -> [EmittedToken] {
        guard !accumulated.isEmpty else { return next }
        guard !next.isEmpty else { return accumulated }

        if usesTailContext {
            let replacementStartFrame = next[0].startFrame
            return accumulated.filter { $0.endFrame <= replacementStartFrame } + next
        }

        let mergedTokenIDs = mergedTokenIDs(
            accumulated.map(\.tokenID),
            appending: next.map(\.tokenID)
        )
        let droppedPrefixCount = accumulated.count + next.count - mergedTokenIDs.count
        return accumulated + next.dropFirst(max(0, droppedPrefixCount))
    }

    func mappedDuration(for durationBin: Int32) throws -> Int {
        let index = Int(durationBin)
        guard Constants.durationBins.indices.contains(index) else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_duration_bin")
        }
        return Constants.durationBins[index]
    }

    static func preferredJointDirectoryURL(in modelDirectoryURL: URL, fileManager: FileManager) -> URL {
        let canonicalURL = modelDirectoryURL.appendingPathComponent(Constants.canonicalJointDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: canonicalURL.path) {
            return canonicalURL
        }
        return modelDirectoryURL.appendingPathComponent(Constants.jointDirectoryName, isDirectory: true)
    }
}
