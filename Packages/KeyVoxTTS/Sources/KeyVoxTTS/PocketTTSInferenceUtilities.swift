@preconcurrency import CoreML
import Foundation

enum PocketTTSInferenceUtilities {
    static func createBeginningOfSequenceEmbedding(_ values: [Float]) throws -> MLMultiArray {
        guard values.count >= PocketTTSConstants.latentDimension else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("BOS embedding has insufficient values: expected %ld, got %ld", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is incomplete. BOS embedding is a technical term; the first %ld is the expected value count and the second the actual count. PocketTTS and Mimi are technical engine names and stay in English."), PocketTTSConstants.latentDimension, values.count))
        }
        let array = try MLMultiArray(shape: [NSNumber(value: PocketTTSConstants.latentDimension)], dataType: .float32)
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.latentDimension)
        values.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            pointer.update(from: baseAddress, count: PocketTTSConstants.latentDimension)
        }
        return array
    }

    static func createNaNSequence() throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, 1, NSNumber(value: PocketTTSConstants.latentDimension)],
            dataType: .float32
        )
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.latentDimension)
        for index in 0..<PocketTTSConstants.latentDimension {
            pointer[index] = .nan
        }
        return array
    }

    static func createSequence(from latent: [Float]) throws -> MLMultiArray {
        guard latent.count >= PocketTTSConstants.latentDimension else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("Latent sequence has insufficient values: expected %ld, got %ld", bundle: .module, comment: "Error shown when reading copied text aloud fails: internal speech data is incomplete. The first %ld is the expected value count and the second the actual count. PocketTTS and Mimi are technical engine names and stay in English."), PocketTTSConstants.latentDimension, latent.count))
        }
        let array = try MLMultiArray(
            shape: [1, 1, NSNumber(value: PocketTTSConstants.latentDimension)],
            dataType: .float32
        )
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: PocketTTSConstants.latentDimension)
        latent.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            pointer.update(from: baseAddress, count: PocketTTSConstants.latentDimension)
        }
        return array
    }

    static func embed(tokenIDs: [Int], constants: PocketTTSConstantsBundle) -> [[Float]] {
        tokenIDs.map { tokenID in
            let clamped = max(0, min(tokenID, PocketTTSConstants.vocabularySize - 1))
            let offset = clamped * PocketTTSConstants.embeddingDimension
            let end = offset + PocketTTSConstants.embeddingDimension
            return Array(constants.textEmbeddingTable[offset..<end])
        }
    }

    static func estimateMaxFrameCount(forTokenCount tokenCount: Int) -> Int {
        let estimatedFrames = (Double(tokenCount) * PocketTTSConstants.estimatedFramesPerToken)
            + Double(PocketTTSConstants.estimatedFrameBasePadding)
        return max(PocketTTSConstants.estimatedFrameBasePadding, Int(estimatedFrames.rounded(.up)))
    }

    static func estimateGenerationFrameLimit(for text: String) -> Int {
        let wordCount = text.split(separator: " ").count
        let estimatedSeconds = Double(wordCount) + 2.0
        return Int((estimatedSeconds * 12.5).rounded(.up))
    }

    static func readFloats(from array: MLMultiArray, count: Int) -> [Float] {
        if array.dataType == .float16 {
            return (0..<count).map { array[$0].floatValue }
        }
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }
}
