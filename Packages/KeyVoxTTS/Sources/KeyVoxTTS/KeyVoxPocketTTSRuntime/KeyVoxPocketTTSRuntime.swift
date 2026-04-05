@preconcurrency import CoreML
import Foundation

public enum KeyVoxTTSComputeMode: Sendable {
    case foreground
    case backgroundSafe
}

public actor KeyVoxPocketTTSRuntime {
    struct ModelSet {
        let condStepModel: MLModel
        let flowLanguageModel: MLModel
        let flowDecoderModel: MLModel
        let mimiDecoderModel: MLModel
    }

    let assetLayout: KeyVoxTTSAssetLayout
    var foregroundModels: ModelSet?
    var backgroundModels: ModelSet?
    var constantsBundle: PocketTTSConstantsBundle?
    var cachedVoices: [KeyVoxTTSVoice: PocketTTSVoiceConditioning] = [:]
    var cachedVoiceKVSnapshots: [KeyVoxTTSVoice: PocketTTSInferenceTypes.KVCacheState] = [:]
    private let computeModeController = ComputeModeController()

    public init(assetLayout: KeyVoxTTSAssetLayout) {
        self.assetLayout = assetLayout
    }

    public func prepareIfNeeded() async throws {
        guard foregroundModels == nil || backgroundModels == nil else { return }

        try validateAssetLayout()
        let loadStart = CFAbsoluteTimeGetCurrent()

        let newForegroundModels = try loadModelSet(computeUnits: .cpuAndGPU)
        Self.log("Loaded foreground PocketTTS models with cpuAndGPU in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - loadStart))s")

        let backgroundLoadStart = CFAbsoluteTimeGetCurrent()
        let newBackgroundModels = try loadModelSet(computeUnits: .cpuOnly)
        Self.log("Loaded background PocketTTS models with cpuOnly in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - backgroundLoadStart))s")

        let newConstantsBundle = try PocketTTSAssetLoader.loadConstants(from: assetLayout)

        foregroundModels = newForegroundModels
        backgroundModels = newBackgroundModels
        constantsBundle = newConstantsBundle
    }

    public func setPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) async {
        await computeModeController.setMode(mode)
        Self.log("Preferred compute mode set to \(mode.logName).")
    }

    public func prepareVoiceIfNeeded(_ voice: KeyVoxTTSVoice) async throws {
        try await prepareIfNeeded()

        let voiceConditioning = try loadVoiceConditioning(voice)
        let currentMode = await computeModeController.mode()
        let prefillModel = currentMode == .backgroundSafe
            ? try modelSet(backgroundModels, modeName: "background").condStepModel
            : try modelSet(foregroundModels, modeName: "foreground").condStepModel

        _ = try await loadVoiceKVSnapshot(
            for: voice,
            voiceConditioning: voiceConditioning,
            model: prefillModel
        )
    }

    public func synthesizeStreaming(
        text: String,
        voice: KeyVoxTTSVoice,
        fastModeEnabled: Bool = false,
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
        let currentMode = await computeModeController.mode()
        let prefillModel = currentMode == .backgroundSafe
            ? try modelSet(backgroundModels, modeName: "background").condStepModel
            : try modelSet(foregroundModels, modeName: "foreground").condStepModel
        let voiceKVSnapshot = try await loadVoiceKVSnapshot(
            for: voice,
            voiceConditioning: voiceConditioning,
            model: prefillModel
        )
        let chunks = PocketTTSChunkPlanner.chunk(
            trimmedText,
            tokenizer: constants.tokenizer,
            fastModeEnabled: fastModeEnabled
        )
        Self.log(
            "Voice prefill completed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - voicePrefillStart))s. Chunks: \(chunks.count)"
        )
        let generator = try KeyVoxPocketTTSStreamGenerator(
            chunks: chunks,
            fastModeEnabled: fastModeEnabled,
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

    static func log(_ message: String) {
        #if DEBUG
        NSLog("[KeyVoxPocketTTSRuntime] %@", message)
        #endif
    }
}
