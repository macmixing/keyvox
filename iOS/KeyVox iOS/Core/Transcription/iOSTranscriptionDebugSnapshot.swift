import Foundation

struct iOSTranscriptionDebugSnapshot: Equatable, Sendable {
    let rawText: String
    let finalText: String
    let wasLikelyNoSpeech: Bool
    let inferenceDuration: TimeInterval
    let pasteDuration: TimeInterval
    let usedDictionaryHintPrompt: Bool
    let captureDuration: TimeInterval
    let outputFrameCount: Int
}
