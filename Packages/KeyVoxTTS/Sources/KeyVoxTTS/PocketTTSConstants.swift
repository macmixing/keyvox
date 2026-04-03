import Foundation

enum PocketTTSConstants {
    static let audioSampleRate = 24_000
    static let samplesPerFrame = 1_920
    static let latentDimension = 32
    static let transformerDimension = 1_024
    static let vocabularySize = 4_001
    static let embeddingDimension = 1_024
    static let flowDecoderSteps = 8
    static let temperature: Float = 0.7
    static let eosThreshold: Float = -4.0
    static let shortTextPadFrames = 3
    static let longTextExtraFrames = 1
    static let extraFramesAfterDetection = 2
    static let shortTextWordThreshold = 5
    static let maxTokensPerChunk = 128
    static let kvCacheLayers = 6
    static let kvCacheMaxLength = 512
    static let maxVoicePromptFrames = 250

    enum ModelName {
        static let condStep = "cond_step"
        static let flowLMStep = "flowlm_step"
        static let flowDecoder = "flow_decoder"
        static let mimiDecoder = "mimi_decoder_v2"
    }
}
