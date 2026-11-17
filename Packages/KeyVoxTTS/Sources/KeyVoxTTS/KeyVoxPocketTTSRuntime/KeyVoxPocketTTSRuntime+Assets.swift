@preconcurrency import CoreML
import Foundation

extension KeyVoxPocketTTSRuntime {
    func validateAssetLayout() throws {
        let requiredModelNames = [
            PocketTTSConstants.ModelName.condStep,
            PocketTTSConstants.ModelName.flowLMStep,
            PocketTTSConstants.ModelName.flowDecoder,
            PocketTTSConstants.ModelName.mimiDecoder,
        ]

        for modelName in requiredModelNames {
            let modelURL = assetLayout.compiledModelURL(named: modelName)
            guard FileManager.default.fileExists(atPath: modelURL.path) else {
                throw KeyVoxTTSError.missingModel(String(format: NSLocalizedString("PocketTTS model %@ is missing.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine model is missing. %@ is a model file name and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), modelName))
            }
        }

        guard FileManager.default.fileExists(atPath: assetLayout.constantsDirectoryURL.path) else {
            throw KeyVoxTTSError.invalidAssetLayout(NSLocalizedString("PocketTTS constants directory is missing.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine folder is missing. PocketTTS and Mimi are technical engine names and stay in English."))
        }
    }

    func constants() throws -> PocketTTSConstantsBundle {
        guard let constantsBundle else {
            throw KeyVoxTTSError.missingAsset(NSLocalizedString("PocketTTS constants are not loaded.", bundle: .module, comment: "Error shown when reading copied text aloud fails: speech engine data was not loaded. PocketTTS and Mimi are technical engine names and stay in English."))
        }
        return constantsBundle
    }

    func loadVoiceConditioning(_ voice: KeyVoxTTSVoice) throws -> PocketTTSVoiceConditioning {
        if let cached = cachedVoices[voice] {
            return cached
        }

        let loaded = try PocketTTSAssetLoader.loadVoice(voice, from: assetLayout)
        cachedVoices[voice] = loaded
        return loaded
    }

    func loadVoiceKVSnapshot(
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

    func loadModelSet(computeUnits: MLComputeUnits) throws -> ModelSet {
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

    func modelSet(_ modelSet: ModelSet?, modeName: String) throws -> ModelSet {
        guard let modelSet else {
            throw KeyVoxTTSError.missingModel(String(format: NSLocalizedString("PocketTTS %@ model set is not loaded.", bundle: .module, comment: "Error shown when reading copied text aloud fails: speech engine models were not loaded. %@ is an internal mode name and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), modeName))
        }
        return modelSet
    }
}
