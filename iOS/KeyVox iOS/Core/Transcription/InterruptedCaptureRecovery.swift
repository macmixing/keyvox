import Foundation

struct InterruptedCaptureRecovery: Codable, Equatable {
    enum Status: String, Codable, Equatable {
        case pending
        case transcribing
        case failed
    }

    let capturedAt: Date
    let captureDuration: TimeInterval
    let maxActiveSignalRunDuration: TimeInterval
    let usedDictionaryHintPrompt: Bool
    let audioFrameCount: Int
    var status: Status
    var failureReason: String?
}

struct InterruptedCaptureRecoveryPayload: Codable, Equatable {
    var recovery: InterruptedCaptureRecovery
    var audioFrames: [Float]
}
