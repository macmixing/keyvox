import Foundation

struct iOSInterruptedCaptureRecovery: Codable, Equatable {
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

struct iOSInterruptedCaptureRecoveryPayload: Codable, Equatable {
    var recovery: iOSInterruptedCaptureRecovery
    var audioFrames: [Float]
}
