@preconcurrency import CoreML
import Foundation

enum PocketTTSKVCacheInference {
    static func emptyState() throws -> PocketTTSInferenceTypes.KVCacheState {
        let shape: [NSNumber] = [2, 1, NSNumber(value: PocketTTSConstants.kvCacheMaxLength), 16, 64]
        var caches: [MLMultiArray] = []
        var positions: [MLMultiArray] = []

        for _ in 0..<PocketTTSConstants.kvCacheLayers {
            let cache = try MLMultiArray(shape: shape, dataType: .float32)
            let cachePointer = cache.dataPointer.bindMemory(to: Float.self, capacity: cache.count)
            cachePointer.initialize(repeating: 0, count: cache.count)
            caches.append(cache)

            let position = try MLMultiArray(shape: [1], dataType: .float32)
            position[0] = 0
            positions.append(position)
        }

        return PocketTTSInferenceTypes.KVCacheState(caches: caches, positions: positions)
    }

    static func cloneState(_ state: PocketTTSInferenceTypes.KVCacheState) throws -> PocketTTSInferenceTypes.KVCacheState {
        var caches: [MLMultiArray] = []
        var positions: [MLMultiArray] = []
        caches.reserveCapacity(state.caches.count)
        positions.reserveCapacity(state.positions.count)

        for cache in state.caches {
            let copy = try MLMultiArray(shape: cache.shape, dataType: cache.dataType)
            let byteCount = byteCount(for: cache)
            if byteCount > 0 {
                copy.dataPointer.copyMemory(from: cache.dataPointer, byteCount: byteCount)
            }
            caches.append(copy)
        }

        for position in state.positions {
            let copy = try MLMultiArray(shape: position.shape, dataType: position.dataType)
            let byteCount = byteCount(for: position)
            if byteCount > 0 {
                copy.dataPointer.copyMemory(from: position.dataPointer, byteCount: byteCount)
            }
            positions.append(copy)
        }

        return PocketTTSInferenceTypes.KVCacheState(caches: caches, positions: positions)
    }

    static func prefillVoice(
        voice: PocketTTSVoiceConditioning,
        model: MLModel
    ) async throws -> PocketTTSInferenceTypes.KVCacheState {
        var state = try emptyState()

        for tokenIndex in 0..<voice.promptLength {
            let token = try conditioningToken(
                values: voice.audioPrompt,
                offset: tokenIndex * PocketTTSConstants.embeddingDimension
            )
            try await runConditioningStep(token: token, state: &state, model: model)
        }

        return state
    }

    static func prefillText(
        embeddings: [[Float]],
        state: inout PocketTTSInferenceTypes.KVCacheState,
        model: MLModel
    ) async throws {
        for embedding in embeddings {
            let token = try conditioningToken(values: embedding, offset: 0)
            try await runConditioningStep(token: token, state: &state, model: model)
        }
    }

    static func prefill(
        voice: PocketTTSVoiceConditioning,
        textEmbeddings: [[Float]],
        model: MLModel
    ) async throws -> PocketTTSInferenceTypes.KVCacheState {
        var state = try await prefillVoice(voice: voice, model: model)
        try await prefillText(embeddings: textEmbeddings, state: &state, model: model)

        return state
    }

    static func generationStep(
        sequence: MLMultiArray,
        beginningOfSequenceEmbedding: MLMultiArray,
        state: inout PocketTTSInferenceTypes.KVCacheState,
        model: MLModel
    ) async throws -> (transformerOut: MLMultiArray, eosLogit: Float) {
        var input: [String: Any] = [
            "sequence": sequence,
            "bos_emb": beginningOfSequenceEmbedding,
        ]
        for layerIndex in 0..<PocketTTSConstants.kvCacheLayers {
            input["cache\(layerIndex)"] = state.caches[layerIndex]
            input["position\(layerIndex)"] = state.positions[layerIndex]
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: input)
        let output = try await model.keyVoxPrediction(from: provider)

        guard let transformer = output.featureValue(for: PocketTTSInferenceTypes.FlowLMOutput.transformerOut)?.multiArrayValue else {
            throw KeyVoxTTSError.inferenceFailure("PocketTTS flow language model output is missing.")
        }
        guard let eosArray = output.featureValue(for: PocketTTSInferenceTypes.FlowLMOutput.eosLogit)?.multiArrayValue else {
            throw KeyVoxTTSError.inferenceFailure("PocketTTS EOS output is missing.")
        }

        for layerIndex in 0..<PocketTTSConstants.kvCacheLayers {
            guard let cache = output.featureValue(for: PocketTTSInferenceTypes.FlowLMOutput.cacheKeys[layerIndex])?.multiArrayValue,
                  let position = output.featureValue(for: PocketTTSInferenceTypes.FlowLMOutput.positionKeys[layerIndex])?.multiArrayValue else {
                throw KeyVoxTTSError.inferenceFailure("PocketTTS generation cache outputs are incomplete.")
            }
            state.caches[layerIndex] = cache
            state.positions[layerIndex] = position
        }

        return (transformer, eosArray[0].floatValue)
    }

    private static func runConditioningStep(
        token: MLMultiArray,
        state: inout PocketTTSInferenceTypes.KVCacheState,
        model: MLModel
    ) async throws {
        var input: [String: Any] = ["conditioning": token]
        for layerIndex in 0..<PocketTTSConstants.kvCacheLayers {
            input["cache\(layerIndex)"] = state.caches[layerIndex]
            input["position\(layerIndex)"] = state.positions[layerIndex]
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: input)
        let output = try await model.keyVoxPrediction(from: provider)

        for layerIndex in 0..<PocketTTSConstants.kvCacheLayers {
            guard let cache = output.featureValue(for: PocketTTSInferenceTypes.CondStepOutput.cacheKeys[layerIndex])?.multiArrayValue,
                  let position = output.featureValue(for: PocketTTSInferenceTypes.CondStepOutput.positionKeys[layerIndex])?.multiArrayValue else {
                throw KeyVoxTTSError.inferenceFailure("PocketTTS conditioning cache outputs are incomplete.")
            }
            state.caches[layerIndex] = cache
            state.positions[layerIndex] = position
        }
    }

    private static func conditioningToken(values: [Float], offset: Int) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, 1, NSNumber(value: PocketTTSConstants.embeddingDimension)],
            dataType: .float32
        )
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.embeddingDimension)
        values.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            pointer.update(from: baseAddress.advanced(by: offset), count: PocketTTSConstants.embeddingDimension)
        }
        return array
    }

    private static func byteCount(for array: MLMultiArray) -> Int {
        switch array.dataType {
        case .float16:
            return array.count * MemoryLayout<UInt16>.size
        case .double:
            return array.count * MemoryLayout<Double>.size
        case .int32:
            return array.count * MemoryLayout<Int32>.size
        default:
            return array.count * MemoryLayout<Float>.size
        }
    }
}
