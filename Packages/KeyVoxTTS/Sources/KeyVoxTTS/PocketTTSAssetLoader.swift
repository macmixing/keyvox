import Foundation

struct PocketTTSConstantsBundle: Sendable {
    let beginningOfSequenceEmbedding: [Float]
    let textEmbeddingTable: [Float]
    let tokenizer: SentencePieceTokenizer
}

struct PocketTTSVoiceConditioning: Sendable {
    let audioPrompt: [Float]
    let promptLength: Int
}

enum PocketTTSAssetLoader {
    static func loadConstants(from layout: KeyVoxTTSAssetLayout) throws -> PocketTTSConstantsBundle {
        let bosURL = layout.constantsDirectoryURL.appendingPathComponent("bos_emb.bin", isDirectory: false)
        let embeddingURL = layout.constantsDirectoryURL.appendingPathComponent("text_embed_table.bin", isDirectory: false)
        let tokenizerURL = layout.constantsDirectoryURL.appendingPathComponent("tokenizer.model", isDirectory: false)

        let bosEmbedding = try loadFloatArray(
            at: bosURL,
            expectedCount: PocketTTSConstants.latentDimension,
            assetName: "bos_emb.bin"
        )
        let embeddingTable = try loadFloatArray(
            at: embeddingURL,
            expectedCount: PocketTTSConstants.vocabularySize * PocketTTSConstants.embeddingDimension,
            assetName: "text_embed_table.bin"
        )
        guard FileManager.default.fileExists(atPath: tokenizerURL.path) else {
            throw KeyVoxTTSError.missingAsset("PocketTTS tokenizer model is missing.")
        }
        let tokenizerData = try Data(contentsOf: tokenizerURL)
        let tokenizer = try SentencePieceTokenizer(modelData: tokenizerData)
        return PocketTTSConstantsBundle(
            beginningOfSequenceEmbedding: bosEmbedding,
            textEmbeddingTable: embeddingTable,
            tokenizer: tokenizer
        )
    }

    static func loadVoice(_ voice: KeyVoxTTSVoice, from layout: KeyVoxTTSAssetLayout) throws -> PocketTTSVoiceConditioning {
        let promptURL = layout.voicePromptURL(for: voice)
        guard FileManager.default.fileExists(atPath: promptURL.path) else {
            throw KeyVoxTTSError.missingAsset("PocketTTS voice prompt for \(voice.rawValue) is missing.")
        }

        let data = try Data(contentsOf: promptURL)
        guard data.count % MemoryLayout<Float>.size == 0 else {
            throw KeyVoxTTSError.invalidAssetData("PocketTTS voice prompt for \(voice.rawValue) has misaligned byte count.")
        }
        let floatCount = data.count / MemoryLayout<Float>.size
        guard floatCount > 0, floatCount % PocketTTSConstants.embeddingDimension == 0 else {
            throw KeyVoxTTSError.invalidAssetData("PocketTTS voice prompt for \(voice.rawValue) has an invalid size.")
        }

        let promptLength = floatCount / PocketTTSConstants.embeddingDimension
        guard promptLength <= PocketTTSConstants.maxVoicePromptFrames else {
            throw KeyVoxTTSError.invalidAssetData("PocketTTS voice prompt for \(voice.rawValue) exceeds the supported length.")
        }

        let values = data.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
        return PocketTTSVoiceConditioning(audioPrompt: values, promptLength: promptLength)
    }

    private static func loadFloatArray(at url: URL, expectedCount: Int, assetName: String) throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KeyVoxTTSError.missingAsset("PocketTTS asset \(assetName) is missing.")
        }

        let data = try Data(contentsOf: url)
        guard data.count % MemoryLayout<Float>.size == 0 else {
            throw KeyVoxTTSError.invalidAssetData("PocketTTS asset \(assetName) has misaligned byte count.")
        }
        let actualCount = data.count / MemoryLayout<Float>.size
        guard actualCount == expectedCount else {
            throw KeyVoxTTSError.invalidAssetData("PocketTTS asset \(assetName) has an unexpected size.")
        }

        return data.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
    }
}
