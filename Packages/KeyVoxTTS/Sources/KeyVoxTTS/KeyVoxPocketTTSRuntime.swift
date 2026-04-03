@preconcurrency import CoreML
import Foundation

public enum KeyVoxTTSComputeMode: Sendable {
    case foreground
    case backgroundSafe
}

public actor KeyVoxPocketTTSRuntime {
    fileprivate struct ModelSet {
        let condStepModel: MLModel
        let flowLanguageModel: MLModel
        let flowDecoderModel: MLModel
        let mimiDecoderModel: MLModel
    }

    private let assetLayout: KeyVoxTTSAssetLayout
    private var foregroundModels: ModelSet?
    private var backgroundModels: ModelSet?
    private var constantsBundle: PocketTTSConstantsBundle?
    private var cachedVoices: [KeyVoxTTSVoice: PocketTTSVoiceConditioning] = [:]
    private var cachedVoiceKVSnapshots: [KeyVoxTTSVoice: PocketTTSInferenceTypes.KVCacheState] = [:]
    private let computeModeController = ComputeModeController()

    public init(assetLayout: KeyVoxTTSAssetLayout) {
        self.assetLayout = assetLayout
    }

    public func prepareIfNeeded() async throws {
        guard foregroundModels == nil || backgroundModels == nil else { return }

        try validateAssetLayout()
        let loadStart = CFAbsoluteTimeGetCurrent()

        foregroundModels = try loadModelSet(computeUnits: .cpuAndGPU)
        Self.log("Loaded foreground PocketTTS models with cpuAndGPU in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - loadStart))s")

        let backgroundLoadStart = CFAbsoluteTimeGetCurrent()
        backgroundModels = try loadModelSet(computeUnits: .cpuOnly)
        Self.log("Loaded background PocketTTS models with cpuOnly in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - backgroundLoadStart))s")
        constantsBundle = try PocketTTSAssetLoader.loadConstants(from: assetLayout)
    }

    public func setPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) async {
        await computeModeController.setMode(mode)
        Self.log("Preferred compute mode set to \(mode.logName).")
    }

    public func synthesizeStreaming(
        text: String,
        voice: KeyVoxTTSVoice,
        seed: UInt64? = nil
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error> {
        try await prepareIfNeeded()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw KeyVoxTTSError.inferenceFailure("PocketTTS requires non-empty text.")
        }
        Self.log("Starting synthesis for text length \(trimmedText.count) chars.")

        let constants = try constants()
        let voiceConditioning = try loadVoiceConditioning(voice)
        let voicePrefillStart = CFAbsoluteTimeGetCurrent()
        let voiceKVSnapshot = try await loadVoiceKVSnapshot(
            for: voice,
            voiceConditioning: voiceConditioning,
            model: try modelSet(foregroundModels, modeName: "foreground").condStepModel
        )
        let chunks = PocketTTSChunkPlanner.chunk(trimmedText, tokenizer: constants.tokenizer)
        Self.log(
            "Voice prefill completed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - voicePrefillStart))s. Chunks: \(chunks.count)"
        )
        let generator = try StreamGenerator(
            chunks: chunks,
            constants: constants,
            voiceConditioning: voiceConditioning,
            foregroundModels: try modelSet(foregroundModels, modeName: "foreground"),
            backgroundModels: try modelSet(backgroundModels, modeName: "background"),
            initialMimiState: try PocketTTSMimiInference.initialState(from: assetLayout),
            beginningOfSequenceEmbedding: try PocketTTSInferenceUtilities.createBeginningOfSequenceEmbedding(constants.beginningOfSequenceEmbedding),
            voiceKVSnapshot: voiceKVSnapshot,
            computeModeController: computeModeController,
            seed: seed ?? UInt64.random(in: 0...UInt64.max)
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                await generator.generate(into: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func validateAssetLayout() throws {
        let requiredModelNames = [
            PocketTTSConstants.ModelName.condStep,
            PocketTTSConstants.ModelName.flowLMStep,
            PocketTTSConstants.ModelName.flowDecoder,
            PocketTTSConstants.ModelName.mimiDecoder,
        ]

        for modelName in requiredModelNames {
            let modelURL = assetLayout.compiledModelURL(named: modelName)
            guard FileManager.default.fileExists(atPath: modelURL.path) else {
                throw KeyVoxTTSError.missingModel("PocketTTS model \(modelName) is missing.")
            }
        }

        guard FileManager.default.fileExists(atPath: assetLayout.constantsDirectoryURL.path) else {
            throw KeyVoxTTSError.invalidAssetLayout("PocketTTS constants directory is missing.")
        }
    }

    private func constants() throws -> PocketTTSConstantsBundle {
        guard let constantsBundle else {
            throw KeyVoxTTSError.missingAsset("PocketTTS constants are not loaded.")
        }
        return constantsBundle
    }

    private func loadVoiceConditioning(_ voice: KeyVoxTTSVoice) throws -> PocketTTSVoiceConditioning {
        if let cached = cachedVoices[voice] {
            return cached
        }

        let loaded = try PocketTTSAssetLoader.loadVoice(voice, from: assetLayout)
        cachedVoices[voice] = loaded
        return loaded
    }

    private func loadVoiceKVSnapshot(
        for voice: KeyVoxTTSVoice,
        voiceConditioning: PocketTTSVoiceConditioning,
        model: MLModel
    ) async throws -> PocketTTSInferenceTypes.KVCacheState {
        if let cachedSnapshot = cachedVoiceKVSnapshots[voice] {
            Self.log("Reusing cached voice prefill for \(voice.rawValue).")
            return try PocketTTSKVCacheInference.cloneState(cachedSnapshot)
        }

        let snapshot = try await PocketTTSKVCacheInference.prefillVoice(
            voice: voiceConditioning,
            model: model
        )
        cachedVoiceKVSnapshots[voice] = snapshot
        Self.log("Cached voice prefill for \(voice.rawValue).")
        return try PocketTTSKVCacheInference.cloneState(snapshot)
    }

    private func loadModelSet(computeUnits: MLComputeUnits) throws -> ModelSet {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits

        return ModelSet(
            condStepModel: try MLModel(
                contentsOf: assetLayout.compiledModelURL(named: PocketTTSConstants.ModelName.condStep),
                configuration: configuration
            ),
            flowLanguageModel: try MLModel(
                contentsOf: assetLayout.compiledModelURL(named: PocketTTSConstants.ModelName.flowLMStep),
                configuration: configuration
            ),
            flowDecoderModel: try MLModel(
                contentsOf: assetLayout.compiledModelURL(named: PocketTTSConstants.ModelName.flowDecoder),
                configuration: configuration
            ),
            mimiDecoderModel: try MLModel(
                contentsOf: assetLayout.compiledModelURL(named: PocketTTSConstants.ModelName.mimiDecoder),
                configuration: configuration
            )
        )
    }

    private func modelSet(_ modelSet: ModelSet?, modeName: String) throws -> ModelSet {
        guard let modelSet else {
            throw KeyVoxTTSError.missingModel("PocketTTS \(modeName) model set is not loaded.")
        }
        return modelSet
    }

    private static func log(_ message: String) {
        NSLog("[KeyVoxPocketTTSRuntime] %@", message)
    }
}

private actor StreamGenerator {
    private enum StreamingPolicy {
        static let batchedFrameCount = 8
    }

    private struct ChunkPlan {
        let rawText: String
        let estimatedFrameCount: Int
    }

    private let chunkPlans: [ChunkPlan]
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
            let estimatedFrameCount = PocketTTSInferenceUtilities.estimateMaxFrameCount(for: chunk)
            return ChunkPlan(
                rawText: chunk,
                estimatedFrameCount: estimatedFrameCount
            )
        }

        self.chunkPlans = chunkPlans
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
            for (chunkIndex, chunkPlan) in chunkPlans.enumerated() {
                if Task.isCancelled { break }
                let chunkStart = CFAbsoluteTimeGetCurrent()

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
                    "Chunk \(chunkIndex + 1)/\(chunkPlans.count) text prefill: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - textPrefillStart))s, chars=\(chunkPlan.rawText.count), tokens=\(tokenIDs.count)"
                )

                let maximumFrameCount = chunkPlan.estimatedFrameCount
                let minimumFramesAfterEOS = normalizedChunk.framesAfterEOS + PocketTTSConstants.extraFramesAfterDetection
                var detectedEOSFrame: Int?
                var sequence = try PocketTTSInferenceUtilities.createNaNSequence()
                var batchedSamples: [Float] = []
                batchedSamples.reserveCapacity(PocketTTSConstants.samplesPerFrame * StreamingPolicy.batchedFrameCount)
                var batchStartFrameIndex = 0
                var generatedFrames = 0

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
                    }
                    if let detectedEOSFrame, frameIndex >= detectedEOSFrame + minimumFramesAfterEOS {
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

                    let reachedBatchSize = (frameIndex - batchStartFrameIndex + 1) >= StreamingPolicy.batchedFrameCount
                    if reachedBatchSize {
                        flushBatch(
                            samples: &batchedSamples,
                            batchStartFrameIndex: batchStartFrameIndex,
                            frameIndex: frameIndex,
                            chunkIndex: chunkIndex,
                            chunkCount: chunkPlans.count,
                            isChunkFinalBatch: false,
                            continuation: continuation
                        )
                    }
                    sequence = try PocketTTSInferenceUtilities.createSequence(from: latent)
                }

                flushBatch(
                    samples: &batchedSamples,
                    batchStartFrameIndex: batchStartFrameIndex,
                    frameIndex: maximumFrameCount - 1,
                    chunkIndex: chunkIndex,
                    chunkCount: chunkPlans.count,
                    isChunkFinalBatch: true,
                    continuation: continuation
                )
                Self.log(
                    "Chunk \(chunkIndex + 1)/\(chunkPlans.count) generated \(generatedFrames) frames in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - chunkStart))s"
                )
            }

            continuation.finish()
        } catch {
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
        isChunkFinalBatch: Bool,
        continuation: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>.Continuation
    ) {
        guard !samples.isEmpty else { return }
        let batchedSampleCount = samples.count

        continuation.yield(
            KeyVoxTTSAudioFrame(
                samples: samples,
                frameIndex: max(batchStartFrameIndex, frameIndex),
                chunkIndex: chunkIndex,
                chunkCount: chunkCount,
                isChunkFinalBatch: isChunkFinalBatch
            )
        )
        Self.log(
            "Chunk \(chunkIndex + 1)/\(chunkCount) yielded batch samples=\(batchedSampleCount) frames=\(max(1, batchedSampleCount / PocketTTSConstants.samplesPerFrame)) finalBatch=\(isChunkFinalBatch)"
        )
        samples.removeAll(keepingCapacity: true)
    }

    private static func log(_ message: String) {
        NSLog("[KeyVoxPocketTTSStream] %@", message)
    }
}

private actor ComputeModeController {
    private var preferredMode: KeyVoxTTSComputeMode = .foreground

    func setMode(_ mode: KeyVoxTTSComputeMode) {
        preferredMode = mode
    }

    func mode() -> KeyVoxTTSComputeMode {
        preferredMode
    }
}

private extension KeyVoxTTSComputeMode {
    var logName: String {
        switch self {
        case .foreground:
            return "foreground"
        case .backgroundSafe:
            return "backgroundSafe"
        }
    }
}
