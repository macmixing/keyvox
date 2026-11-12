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
            throw KeyVoxTTSError.missingAsset(NSLocalizedString("PocketTTS tokenizer model is missing.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is missing. PocketTTS and Mimi are technical engine names and stay in English."))
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
            throw KeyVoxTTSError.missingAsset(String(format: NSLocalizedString("PocketTTS voice prompt for %@ is missing.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a voice file is missing. %@ is the voice identifier and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), voice.rawValue))
        }

        let data = try Data(contentsOf: promptURL)
        guard data.count % MemoryLayout<Float>.size == 0 else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("PocketTTS voice prompt for %@ has misaligned byte count.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a voice file is damaged. %@ is the voice identifier and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), voice.rawValue))
        }
        let floatCount = data.count / MemoryLayout<Float>.size
        guard floatCount > 0, floatCount % PocketTTSConstants.embeddingDimension == 0 else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("PocketTTS voice prompt for %@ has an invalid size.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a voice file is damaged. %@ is the voice identifier and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), voice.rawValue))
        }

        let promptLength = floatCount / PocketTTSConstants.embeddingDimension
        guard promptLength <= PocketTTSConstants.maxVoicePromptFrames else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("PocketTTS voice prompt for %@ exceeds the supported length.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a voice file is too long. %@ is the voice identifier and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), voice.rawValue))
        }

        let values = data.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
        return PocketTTSVoiceConditioning(audioPrompt: values, promptLength: promptLength)
    }

    private static func loadFloatArray(at url: URL, expectedCount: Int, assetName: String) throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KeyVoxTTSError.missingAsset(String(format: NSLocalizedString("PocketTTS asset %@ is missing.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is missing. %@ is a file name and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), assetName))
        }

        let data = try Data(contentsOf: url)
        guard data.count % MemoryLayout<Float>.size == 0 else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("PocketTTS asset %@ has misaligned byte count.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is damaged. %@ is a file name and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), assetName))
        }
        let actualCount = data.count / MemoryLayout<Float>.size
        guard actualCount == expectedCount else {
            throw KeyVoxTTSError.invalidAssetData(String(format: NSLocalizedString("PocketTTS asset %@ has an unexpected size.", bundle: .module, comment: "Error shown when reading copied text aloud fails: a speech engine file is damaged. %@ is a file name and stays as written. PocketTTS and Mimi are technical engine names and stay in English."), assetName))
        }

        return data.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
    }
}
