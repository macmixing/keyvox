@preconcurrency import CoreML
import Foundation

enum PocketTTSFlowInference {
    static func decodeLatent(
        transformerOut: MLMultiArray,
        model: MLModel,
        randomNumberGenerator: inout SeededRandomNumberGenerator,
        temperature: Float
    ) async throws -> [Float] {
        let flattened = try flattenedTransformerOutput(transformerOut)
        let stepSize: Float = 1 / Float(PocketTTSConstants.flowDecoderSteps)

        var latent = [Float](repeating: 0, count: PocketTTSConstants.latentDimension)
        let noiseScale = sqrtf(temperature)
        for index in latent.indices {
            latent[index] = Float.gaussian(using: &randomNumberGenerator) * noiseScale
        }

        for step in 0..<PocketTTSConstants.flowDecoderSteps {
            let startTime = Float(step) * stepSize
            let endTime = Float(step + 1) * stepSize
            let velocity = try await flowStep(
                transformerOut: flattened,
                latent: latent,
                startTime: startTime,
                endTime: endTime,
                model: model
            )
            for index in latent.indices {
                latent[index] += velocity[index] * stepSize
            }
        }

        return latent
    }

    private static func flattenedTransformerOutput(_ array: MLMultiArray) throws -> MLMultiArray {
        let flattened = try MLMultiArray(
            shape: [1, NSNumber(value: PocketTTSConstants.transformerDimension)],
            dataType: .float32
        )
        let source = array.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.transformerDimension)
        let destination = flattened.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.transformerDimension)
        destination.update(from: source, count: PocketTTSConstants.transformerDimension)
        return flattened
    }

    private static func flowStep(
        transformerOut: MLMultiArray,
        latent: [Float],
        startTime: Float,
        endTime: Float,
        model: MLModel
    ) async throws -> [Float] {
        let latentArray = try MLMultiArray(shape: [1, NSNumber(value: PocketTTSConstants.latentDimension)], dataType: .float32)
        let latentPointer = latentArray.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.latentDimension)
        latent.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            latentPointer.update(from: baseAddress, count: PocketTTSConstants.latentDimension)
        }

        let startArray = try MLMultiArray(shape: [1, 1], dataType: .float32)
        startArray[0] = NSNumber(value: startTime)
        let endArray = try MLMultiArray(shape: [1, 1], dataType: .float32)
        endArray[0] = NSNumber(value: endTime)

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "transformer_out": transformerOut,
            "latent": latentArray,
            "s": startArray,
            "t": endArray,
        ])
        let output = try await model.keyVoxPrediction(from: provider)
        guard let outputName = output.featureNames.first,
              let velocityArray = output.featureValue(for: outputName)?.multiArrayValue else {
            throw KeyVoxTTSError.inferenceFailure("PocketTTS flow decoder output is missing.")
        }
        return PocketTTSInferenceUtilities.readFloats(from: velocityArray, count: PocketTTSConstants.latentDimension)
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    init(seed: UInt64) {
        var value = seed
        func nextSplit() -> UInt64 {
            value &+= 0x9E37_79B9_7F4A_7C15
            var z = value
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        state = (nextSplit(), nextSplit(), nextSplit(), nextSplit())
    }

    mutating func next() -> UInt64 {
        let result = ((state.1 &* 5) << 7 | (state.1 &* 5) >> (64 - 7)) &* 9
        let t = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = (state.3 << 45) | (state.3 >> (64 - 45))
        return result
    }
}

private extension Float {
    static func gaussian(using randomNumberGenerator: inout some RandomNumberGenerator) -> Float {
        let u1 = Float.random(in: Float.leastNonzeroMagnitude...1, using: &randomNumberGenerator)
        let u2 = Float.random(in: 0...1, using: &randomNumberGenerator)
        return sqrtf(-2 * logf(u1)) * cosf(2 * .pi * u2)
    }
}
