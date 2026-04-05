@preconcurrency import CoreML
import Foundation

actor KeyVoxPocketTTSStreamGenerator {
    private enum StreamingPolicy {
        static let defaultBatchedFrameCount = 8
    }

    private struct ChunkPlan {
        let rawText: String
        let tokenCount: Int
        let estimatedFrameCount: Int
        let generationFrameLimit: Int
        let debugID: String
        let debugPreview: String
    }

    private let chunkPlans: [ChunkPlan]
    private let fastModeEnabled: Bool
    private let constants: PocketTTSConstantsBundle
    private let voiceConditioning: PocketTTSVoiceConditioning
    private let foregroundModels: KeyVoxPocketTTSRuntime.ModelSet
    private let backgroundModels: KeyVoxPocketTTSRuntime.ModelSet
    private var mimiState: PocketTTSInferenceTypes.MimiState
    private let beginningOfSequenceEmbedding: MLMultiArray
    private let voiceKVSnapshot: PocketTTSInferenceTypes.KVCacheState
    private let computeModeController: ComputeModeController
    private var randomNumberGenerator: SeededRandomNumberGenerator

    init(
        chunks: [String],
        fastModeEnabled: Bool,
        constants: PocketTTSConstantsBundle,
        voiceConditioning: PocketTTSVoiceConditioning,
        foregroundModels: KeyVoxPocketTTSRuntime.ModelSet,
        backgroundModels: KeyVoxPocketTTSRuntime.ModelSet,
        initialMimiState: PocketTTSInferenceTypes.MimiState,
        beginningOfSequenceEmbedding: MLMultiArray,
        voiceKVSnapshot: PocketTTSInferenceTypes.KVCacheState,
        computeModeController: ComputeModeController,
        seed: UInt64
    ) throws {
        guard !chunks.isEmpty else {
            throw KeyVoxTTSError.inferenceFailure("PocketTTS could not derive any synthesis chunks.")
        }

        let chunkPlans = chunks.map { chunk in
            let normalizedChunk = PocketTTSChunkPlanner.normalize(chunk)
            let tokenCount = constants.tokenizer.encode(normalizedChunk.text).count
            let estimatedFrameCount = PocketTTSInferenceUtilities.estimateMaxFrameCount(forTokenCount: tokenCount)
            let generationFrameLimit = PocketTTSInferenceUtilities.estimateGenerationFrameLimit(for: chunk)
            let normalizedPreview = chunk
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let debugPreview = String(normalizedPreview.prefix(80))
            let debugID = Self.chunkDebugID(for: chunk)
            return ChunkPlan(
                rawText: chunk,
                tokenCount: tokenCount,
                estimatedFrameCount: estimatedFrameCount,
                generationFrameLimit: generationFrameLimit,
                debugID: debugID,
                debugPreview: debugPreview
            )
        }

        self.chunkPlans = chunkPlans
        self.fastModeEnabled = fastModeEnabled
        self.constants = constants
        self.voiceConditioning = voiceConditioning
        self.foregroundModels = foregroundModels
        self.backgroundModels = backgroundModels
        self.mimiState = initialMimiState
        self.beginningOfSequenceEmbedding = beginningOfSequenceEmbedding
        self.voiceKVSnapshot = voiceKVSnapshot
        self.computeModeController = computeModeController
        self.randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
    }

    func generate(into continuation: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>.Continuation) async {
        do {
            var emittedSampleCount = 0

            for (chunkIndex, chunkPlan) in chunkPlans.enumerated() {
                if Task.isCancelled { break }
                let chunkStart = CFAbsoluteTimeGetCurrent()
                let futureEstimatedSampleCount = chunkPlans.dropFirst(chunkIndex + 1).reduce(into: 0) { partialResult, plan in
                    partialResult += plan.estimatedFrameCount * PocketTTSConstants.samplesPerFrame
                }
                Self.log(
                    "Chunk \(chunkIndex + 1)/\(chunkPlans.count) start id=\(chunkPlan.debugID)"
                )

                let normalizedChunk = PocketTTSChunkPlanner.normalize(chunkPlan.rawText)
                let tokenIDs = constants.tokenizer.encode(normalizedChunk.text)
                let embeddings = PocketTTSInferenceUtilities.embed(tokenIDs: tokenIDs, constants: constants)
                var kvState = try PocketTTSKVCacheInference.cloneState(voiceKVSnapshot)
                let textPrefillStart = CFAbsoluteTimeGetCurrent()
                let prefillModels = await activeModelSet()
                try await PocketTTSKVCacheInference.prefillText(
                    embeddings: embeddings,
                    state: &kvState,
                    model: prefillModels.condStepModel
                )
                Self.log(
                    "Chunk \(chunkIndex + 1)/\(chunkPlans.count) text prefill: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - textPrefillStart))s, id=\(chunkPlan.debugID), chars=\(chunkPlan.rawText.count), tokens=\(tokenIDs.count), estimatedFrames=\(chunkPlan.estimatedFrameCount), generationLimit=\(chunkPlan.generationFrameLimit)"
                )

                let maximumFrameCount = max(chunkPlan.estimatedFrameCount, chunkPlan.generationFrameLimit)
                let minimumFramesAfterEOS = normalizedChunk.framesAfterEOS + PocketTTSConstants.extraFramesAfterDetection
                var detectedEOSFrame: Int?
                var sequence = try PocketTTSInferenceUtilities.createNaNSequence()
                var batchedSamples: [Float] = []
                batchedSamples.reserveCapacity(
                    PocketTTSConstants.samplesPerFrame * batchedFrameCount(for: chunkIndex)
                )
                var batchStartFrameIndex = 0
                var generatedFrames = 0
                var chunkEmittedSampleCount = 0

                for frameIndex in 0..<maximumFrameCount {
                    if Task.isCancelled { break }
                    let activeModels = await activeModelSet()

                    let step = try await PocketTTSKVCacheInference.generationStep(
                        sequence: sequence,
                        beginningOfSequenceEmbedding: beginningOfSequenceEmbedding,
                        state: &kvState,
                        model: activeModels.flowLanguageModel
                    )

                    if step.eosLogit > PocketTTSConstants.eosThreshold, detectedEOSFrame == nil {
                        detectedEOSFrame = frameIndex
                        Self.log(
                            "Chunk \(chunkIndex + 1)/\(chunkPlans.count) detected EOS id=\(chunkPlan.debugID) frame=\(frameIndex) eosLogit=\(String(format: "%.3f", step.eosLogit)) minimumFramesAfterEOS=\(minimumFramesAfterEOS)"
                        )
                    }
                    if let detectedEOSFrame, frameIndex >= detectedEOSFrame + minimumFramesAfterEOS {
                        Self.log(
                            "Chunk \(chunkIndex + 1)/\(chunkPlans.count) stopping after EOS id=\(chunkPlan.debugID) stopFrame=\(frameIndex) generatedFrames=\(generatedFrames)"
                        )
                        break
                    }

                    let latent = try await decodeLatent(
                        transformerOut: step.transformerOut,
                        model: activeModels.flowDecoderModel
                    )
                    let samples = try await decodeSamples(
                        from: latent,
                        model: activeModels.mimiDecoderModel
                    )
                    if batchedSamples.isEmpty {
                        batchStartFrameIndex = frameIndex
                    }
                    batchedSamples.append(contentsOf: samples)
                    generatedFrames += 1

                    let reachedBatchSize = (frameIndex - batchStartFrameIndex + 1) >= batchedFrameCount(for: chunkIndex)
                    if reachedBatchSize {
                        let estimatedChunkRemainingSampleCount = max(
                            0,
                            (chunkPlan.estimatedFrameCount * PocketTTSConstants.samplesPerFrame)
                                - (chunkEmittedSampleCount + batchedSamples.count)
                        )
                        flushBatch(
                            samples: &batchedSamples,
                            batchStartFrameIndex: batchStartFrameIndex,
                            frameIndex: frameIndex,
                            chunkIndex: chunkIndex,
                            chunkCount: chunkPlans.count,
                            chunkDebugID: chunkPlan.debugID,
                            isChunkFinalBatch: false,
                            remainingEstimatedSampleCount: futureEstimatedSampleCount + estimatedChunkRemainingSampleCount,
                            emittedSampleCount: &emittedSampleCount,
                            chunkEmittedSampleCount: &chunkEmittedSampleCount,
                            continuation: continuation
                        )
                    }
                    sequence = try PocketTTSInferenceUtilities.createSequence(from: latent)
                }

                if batchedSamples.isEmpty == false {
                    let numberOfFrames = (batchedSamples.count + PocketTTSConstants.samplesPerFrame - 1) / PocketTTSConstants.samplesPerFrame
                    let finalFrameIndex = batchStartFrameIndex + numberOfFrames - 1
                    flushBatch(
                        samples: &batchedSamples,
                        batchStartFrameIndex: batchStartFrameIndex,
                        frameIndex: finalFrameIndex,
                        chunkIndex: chunkIndex,
                        chunkCount: chunkPlans.count,
                        chunkDebugID: chunkPlan.debugID,
                        isChunkFinalBatch: true,
                        remainingEstimatedSampleCount: futureEstimatedSampleCount,
                        chunkGeneratedSampleCount: generatedFrames * PocketTTSConstants.samplesPerFrame,
                        chunkGenerationDurationSeconds: CFAbsoluteTimeGetCurrent() - chunkStart,
                        emittedSampleCount: &emittedSampleCount,
                        chunkEmittedSampleCount: &chunkEmittedSampleCount,
                        continuation: continuation
                    )
                } else {
                    flushBatch(
                        samples: &batchedSamples,
                        batchStartFrameIndex: batchStartFrameIndex,
                        frameIndex: batchStartFrameIndex,
                        chunkIndex: chunkIndex,
                        chunkCount: chunkPlans.count,
                        chunkDebugID: chunkPlan.debugID,
                        isChunkFinalBatch: true,
                        remainingEstimatedSampleCount: futureEstimatedSampleCount,
                        chunkGeneratedSampleCount: generatedFrames * PocketTTSConstants.samplesPerFrame,
                        chunkGenerationDurationSeconds: CFAbsoluteTimeGetCurrent() - chunkStart,
                        emittedSampleCount: &emittedSampleCount,
                        chunkEmittedSampleCount: &chunkEmittedSampleCount,
                        continuation: continuation
                    )
                }
                Self.log(
                    "Chunk \(chunkIndex + 1)/\(chunkPlans.count) generated \(generatedFrames) frames in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - chunkStart))s id=\(chunkPlan.debugID) tokenCount=\(chunkPlan.tokenCount) generationLimit=\(chunkPlan.generationFrameLimit)"
                )
            }

            Self.log("Stream generation completed normally.")
            continuation.finish()
        } catch {
            Self.log("Stream generation failed: \(error.localizedDescription)")
            continuation.finish(throwing: error)
        }
    }

    private func decodeLatent(transformerOut: MLMultiArray, model: MLModel) async throws -> [Float] {
        var localGenerator = randomNumberGenerator
        let latent = try await PocketTTSFlowInference.decodeLatent(
            transformerOut: transformerOut,
            model: model,
            randomNumberGenerator: &localGenerator,
            temperature: PocketTTSConstants.temperature
        )
        randomNumberGenerator = localGenerator
        return latent
    }

    private func decodeSamples(from latent: [Float], model: MLModel) async throws -> [Float] {
        var localState = mimiState
        let samples = try await PocketTTSMimiInference.decodeFrame(
            latent: latent,
            state: &localState,
            model: model
        )
        mimiState = localState
        return samples
    }

    private func activeModelSet() async -> KeyVoxPocketTTSRuntime.ModelSet {
        switch await computeModeController.mode() {
        case .foreground:
            return foregroundModels
        case .backgroundSafe:
            return backgroundModels
        }
    }

    private func flushBatch(
        samples: inout [Float],
        batchStartFrameIndex: Int,
        frameIndex: Int,
        chunkIndex: Int,
        chunkCount: Int,
        chunkDebugID: String,
        isChunkFinalBatch: Bool,
        remainingEstimatedSampleCount: Int,
        chunkGeneratedSampleCount: Int? = nil,
        chunkGenerationDurationSeconds: Double? = nil,
        emittedSampleCount: inout Int,
        chunkEmittedSampleCount: inout Int,
        continuation: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>.Continuation
    ) {
        guard !samples.isEmpty || isChunkFinalBatch else { return }
        let emittedSamples = samples
        let batchedSampleCount = emittedSamples.count
        let nextEmittedSampleCount = emittedSampleCount + batchedSampleCount
        let clampedRemainingEstimatedSampleCount = max(0, remainingEstimatedSampleCount)

        continuation.yield(
            KeyVoxTTSAudioFrame(
                samples: emittedSamples,
                frameIndex: max(batchStartFrameIndex, frameIndex),
                chunkIndex: chunkIndex,
                chunkCount: chunkCount,
                isChunkFinalBatch: isChunkFinalBatch,
                chunkDebugID: chunkDebugID,
                estimatedRemainingSampleCount: clampedRemainingEstimatedSampleCount,
                chunkGeneratedSampleCount: chunkGeneratedSampleCount,
                chunkGenerationDurationSeconds: chunkGenerationDurationSeconds
            )
        )
        emittedSampleCount = nextEmittedSampleCount
        chunkEmittedSampleCount += batchedSampleCount
        let emittedFrameCount = batchedSampleCount == 0
            ? 0
            : max(1, batchedSampleCount / PocketTTSConstants.samplesPerFrame)
        Self.log(
            "Chunk \(chunkIndex + 1)/\(chunkCount) yielded batch id=\(chunkDebugID) samples=\(batchedSampleCount) frames=\(emittedFrameCount) remainingEstimatedSamples=\(clampedRemainingEstimatedSampleCount) finalBatch=\(isChunkFinalBatch)"
        )
        samples.removeAll(keepingCapacity: true)
    }

    private func batchedFrameCount(for chunkIndex: Int) -> Int {
        guard fastModeEnabled else {
            return StreamingPolicy.defaultBatchedFrameCount
        }
        if chunkIndex == 0 {
            return PocketTTSConstants.fastModeInitialBatchedFrameCount
        }
        return PocketTTSConstants.fastModeSteadyStateBatchedFrameCount
    }

    private static func chunkDebugID(for text: String) -> String {
        let scalars = text.unicodeScalars.map(\.value)
        var hash: UInt64 = 14_695_981_039_346_656_037
        for scalar in scalars {
            hash ^= UInt64(scalar)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16, uppercase: false)
    }

    private static func log(_ message: String) {
        NSLog("[KeyVoxPocketTTSStream] %@", message)
    }
}
