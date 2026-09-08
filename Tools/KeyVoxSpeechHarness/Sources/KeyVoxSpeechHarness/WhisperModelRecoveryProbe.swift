import Foundation
import KeyVoxCore

/// Exercises the existing service lifecycle without installing or modifying files.
@MainActor
enum WhisperModelRecoveryProbe {
    enum Failure: Error { case invalidInputs, unexpectedResult }

    private struct Report: Encodable {
        let stage: String
        let fileAvailable: Bool
        let resultPresent: Bool
        let hasSpeech: Bool
        let isTranscribing: Bool
    }

    static func run(modelPath: String, invalidModelPath: String, audioPath: String) async throws {
        guard modelPath != invalidModelPath,
              FileManager.default.fileExists(atPath: modelPath),
              FileManager.default.fileExists(atPath: invalidModelPath) else {
            throw Failure.invalidInputs
        }
        let frames = try SpeechAudioFileLoader.load(url: URL(fileURLWithPath: audioPath))
        guard !frames.isEmpty else { throw Failure.invalidInputs }
        var selectedPath: String?
        let service = WhisperService(modelPathResolver: { selectedPath })
        defer { service.unloadModel() }

        try await measure(service, frames: frames, stage: "missing", expectedSpeech: false,
                          expectedResultPresent: true, expectedFileAvailable: false)
        selectedPath = invalidModelPath
        service.unloadModel()
        try await measure(service, frames: frames, stage: "invalid", expectedSpeech: false,
                          expectedResultPresent: false, expectedFileAvailable: true)
        selectedPath = modelPath
        service.unloadModel()
        try await measure(service, frames: frames, stage: "recovered", expectedSpeech: true,
                          expectedResultPresent: true, expectedFileAvailable: true)
        service.unloadModel()
        try await measure(service, frames: frames, stage: "reloaded", expectedSpeech: true,
                          expectedResultPresent: true, expectedFileAvailable: true)
    }

    private static func measure(
        _ service: WhisperService, frames: [Float], stage: String,
        expectedSpeech: Bool, expectedResultPresent: Bool, expectedFileAvailable: Bool
    ) async throws {
        let fileAvailable = service.isModelReady
        let result: TranscriptionProviderResult? = await withCheckedContinuation { continuation in
            service.transcribe(audioFrames: frames) { continuation.resume(returning: $0) }
        }
        let report = Report(stage: stage, fileAvailable: fileAvailable,
                            resultPresent: result != nil, hasSpeech: result?.text.isEmpty == false,
                            isTranscribing: service.isTranscribing)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
        guard report.hasSpeech == expectedSpeech, !report.isTranscribing,
              report.resultPresent == expectedResultPresent,
              report.fileAvailable == expectedFileAvailable else { throw Failure.unexpectedResult }
    }
}
