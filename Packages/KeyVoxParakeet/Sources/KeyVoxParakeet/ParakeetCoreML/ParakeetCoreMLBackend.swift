import Foundation
import CoreML

internal final class ParakeetCoreMLBackend: ParakeetRuntimeBackend {
    let preprocessorModel: MLModel
    let encoderModel: MLModel
    let decoderModel: MLModel
    let jointModel: MLModel
    let vocabulary: ParakeetVocabulary
    let blankTokenID: Int32
    let lock = NSLock()
    var activeRequestID = UUID()

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
        var detectedLanguageCode: String?
        var detectedLanguageName: String?
        var mergedTokens: [EmittedToken] = []
        var noSpeechProbability: Float?

        for window in Self.decodeWindows(forFrameCount: audioFrames.count) {
            await Task.yield()
            try throwIfCancelled(requestID)

            let chunkFrames = Array(audioFrames[window.startFrame..<window.endFrame])
            let decodedChunk = try decodeChunk(
                audioFrames: chunkFrames,
                params: params,
                requestID: requestID,
                startFrame: window.startFrame
            )
            await Task.yield()
            try throwIfCancelled(requestID)

            if detectedLanguageCode == nil {
                detectedLanguageCode = decodedChunk.detectedLanguageCode
                detectedLanguageName = decodedChunk.detectedLanguageName
            }

            mergedTokens = Self.mergedTokens(
                mergedTokens,
                appending: decodedChunk.emittedTokens,
                usesTailContext: window.usesTailContext
            )

            if let chunkNoSpeechProbability = decodedChunk.noSpeechProbability {
                noSpeechProbability = max(noSpeechProbability ?? 0, chunkNoSpeechProbability)
            }
        }

        let mergedTokenIDs = mergedTokens.map(\.tokenID)
        let mergedText = vocabulary.decodedText(from: mergedTokenIDs)
        let confidenceTotal = mergedTokens.reduce(Float(0)) { $0 + $1.confidence }
        let averageConfidence = !mergedTokens.isEmpty
            ? confidenceTotal / Float(mergedTokens.count)
            : nil
        let segments = mergedText.isEmpty
            ? []
            : [
                ParakeetSegment(
                    startTime: 0,
                    endTime: milliseconds(forFrameCount: audioFrames.count),
                    text: mergedText,
                    confidence: averageConfidence,
                    noSpeechProbability: noSpeechProbability
                )
            ]

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

    func beginRequest() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let requestID = UUID()
        activeRequestID = requestID
        return requestID
    }

    func isCurrentRequest(_ requestID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeRequestID == requestID
    }

    func throwIfCancelled(_ requestID: UUID) throws {
        if Task.isCancelled || !isCurrentRequest(requestID) {
            throw ParakeetError.cancelled
        }
    }

    func debugLog(_ message: String) {
#if DEBUG
        print("[ParakeetCoreML] \(message)")
#endif
    }
}
