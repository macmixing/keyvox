@preconcurrency import CoreML
import Foundation

enum PocketTTSMimiInference {
    static func initialState(from layout: KeyVoxTTSAssetLayout) throws -> PocketTTSInferenceTypes.MimiState {
        let manifestURL = layout.constantsDirectoryURL.appendingPathComponent("manifest.json", isDirectory: false)
        let stateDirectoryURL = layout.constantsDirectoryURL.appendingPathComponent("mimi_init_state", isDirectory: true)

        let manifestData = try Data(contentsOf: manifestURL)
        guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let stateManifest = manifest["mimi_init_state"] as? [String: Any] else {
            throw KeyVoxTTSError.invalidAssetData(NSLocalizedString("PocketTTS Mimi manifest is invalid.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is damaged. PocketTTS and Mimi are technical engine names and stay in English."))
        }

        var tensors: [String: MLMultiArray] = [:]
        for (name, rawInfo) in stateManifest {
            guard let info = rawInfo as? [String: Any],
                  let shape = info["shape"] as? [Int],
                  let byteCount = info["bytes"] as? Int else {
                continue
            }

            let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .float32)
            if byteCount > 0 && !shape.contains(0) {
                let data = try Data(contentsOf: stateDirectoryURL.appendingPathComponent(name + ".bin", isDirectory: false))
                
                let expectedBytes = shape.reduce(1, *) * MemoryLayout<Float>.size
                guard data.count >= expectedBytes else {
                    throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("PocketTTS Mimi state tensor %@ has insufficient data: expected %ld bytes, got %ld", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is incomplete. %@ is an internal tensor name and stays as written; the first %ld is the expected byte count and the second the actual byte count. PocketTTS and Mimi are technical engine names and stay in English."), name, expectedBytes, data.count))
                }
                
                let copyCount = expectedBytes / MemoryLayout<Float>.size
                let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: copyCount)
                data.withUnsafeBytes { rawBuffer in
                    let source = rawBuffer.bindMemory(to: Float.self)
                    guard let baseAddress = source.baseAddress else { return }
                    pointer.update(from: baseAddress, count: copyCount)
                }
            }
            tensors[name] = array
        }

        for scalarName in ["attn0_offset", "attn0_end_offset", "attn1_offset", "attn1_end_offset"] where tensors[scalarName] == nil {
            let scalar = try MLMultiArray(shape: [1], dataType: .float32)
            scalar[0] = 0
            tensors[scalarName] = scalar
        }

        return PocketTTSInferenceTypes.MimiState(tensors: tensors)
    }

    static func decodeFrame(
        latent: [Float],
        state: inout PocketTTSInferenceTypes.MimiState,
        model: MLModel
    ) async throws -> [Float] {
        guard latent.count >= PocketTTSConstants.latentDimension else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("Latent vector has insufficient values: expected %ld, got %ld", bundle: .module, comment: "Error shown when reading copied text aloud fails: internal speech data is incomplete. The first %ld is the expected value count and the second the actual count. PocketTTS and Mimi are technical engine names and stay in English."), PocketTTSConstants.latentDimension, latent.count))
        }
        
        let latentArray = try MLMultiArray(shape: [1, NSNumber(value: PocketTTSConstants.latentDimension)], dataType: .float32)
        let latentPointer = latentArray.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.latentDimension)
        latent.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            latentPointer.update(from: baseAddress, count: PocketTTSConstants.latentDimension)
        }

        var input: [String: Any] = ["latent": latentArray]
        for (name, tensor) in state.tensors {
            input[name] = tensor
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: input)
        let output = try await model.keyVoxPrediction(from: provider)
        guard let audioArray = output.featureValue(for: PocketTTSInferenceTypes.MimiOutput.audio)?.multiArrayValue else {
            throw KeyVoxTTSError.inferenceFailure(NSLocalizedString("PocketTTS Mimi audio output is missing.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine step produced no audio. PocketTTS and Mimi are technical engine names and stay in English."))
        }

        for (inputName, outputName) in PocketTTSInferenceTypes.MimiOutput.stateMappings {
            guard let updatedTensor = output.featureValue(for: outputName)?.multiArrayValue else {
                throw KeyVoxTTSError.inferenceFailure(NSLocalizedString("PocketTTS Mimi state output is incomplete.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine step produced incomplete output. PocketTTS and Mimi are technical engine names and stay in English."))
            }
            state.tensors[inputName] = updatedTensor
        }

        return PocketTTSInferenceUtilities.readFloats(from: audioArray, count: PocketTTSConstants.samplesPerFrame)
    }
}
