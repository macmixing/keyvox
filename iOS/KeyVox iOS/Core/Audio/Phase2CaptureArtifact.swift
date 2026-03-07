import Foundation

struct Phase2CaptureArtifact: Codable, Equatable, Sendable {
    let capturedAt: Date
    let sampleRate: Double
    let snapshotFrameCount: Int
    let outputFrameCount: Int
    let captureDuration: TimeInterval
    let hadActiveSignal: Bool
    let wasAbsoluteSilence: Bool
    let wasLikelySilence: Bool
    let wasLongTrueSilence: Bool
    let maxActiveSignalRunDuration: TimeInterval
    let currentCaptureDeviceName: String
    let snapshotWAVURL: URL
    let transcriptionInputWAVURL: URL?
    let metadataURL: URL
}

struct Phase2CaptureWriteRequest: Sendable {
    let capturedAt: Date
    let sampleRate: Double
    let snapshotFrames: [Float]
    let outputFrames: [Float]
    let captureDuration: TimeInterval
    let hadActiveSignal: Bool
    let wasAbsoluteSilence: Bool
    let wasLikelySilence: Bool
    let wasLongTrueSilence: Bool
    let maxActiveSignalRunDuration: TimeInterval
    let currentCaptureDeviceName: String
}

protocol Phase2CaptureArtifactWriting {
    func writeLatestCapture(_ request: Phase2CaptureWriteRequest) async throws -> Phase2CaptureArtifact
}
