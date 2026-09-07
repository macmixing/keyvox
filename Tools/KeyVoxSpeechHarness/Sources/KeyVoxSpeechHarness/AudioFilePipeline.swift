import Foundation
import KeyVoxCore

/// Exercises the production file loader, VAD, and transcription service together.
enum AudioFilePipeline {
    enum Failure: Error { case modelUnavailable, transcriptionFailed }

    @MainActor
    static func run(modelPath: String, audioPath: String, languageCode: String?) async throws {
        let service = WhisperService(modelPathResolver: { modelPath })
        guard service.isModelReady else { throw Failure.modelUnavailable }
        defer { service.unloadModel() }
        let result: TranscriptionProviderResult? = await withCheckedContinuation { continuation in
            service.transcribe(audioURL: URL(fileURLWithPath: audioPath)) { result in
                continuation.resume(returning: result)
            }
        }
        guard let result else { throw Failure.transcriptionFailed }
        try await CoreProcessing.run(text: result.text,
                                     languageCode: languageCode ?? result.languageCode,
                                     detectedLanguageCode: result.languageCode)
    }
}
