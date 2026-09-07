import Foundation
import KeyVoxCore
import KeyVoxParakeetNative

enum ParakeetFilePipeline {
    enum Failure: Error { case modelUnavailable, transcriptionFailed }

    @MainActor
    static func run(modelPath: String, audioPath: String, languageCode: String?) async throws {
        let frames = try await Task.detached {
            try SpeechAudioFileLoader.load(url: URL(fileURLWithPath: audioPath))
        }.value
        let service = ParakeetService(
            modelURLResolver: { URL(fileURLWithPath: modelPath) },
            backendFactory: { try NativeParakeetBackend(modelURL: $0) }
        )
        guard service.isModelReady else { throw Failure.modelUnavailable }
        defer { service.unloadModel() }
        let result: TranscriptionProviderResult? = await withCheckedContinuation { continuation in
            service.transcribe(audioFrames: frames, useDictionaryHintPrompt: false,
                               enableAutoParagraphs: true) { result in
                continuation.resume(returning: result)
            }
        }
        guard let result else { throw Failure.transcriptionFailed }
        try await CoreProcessing.run(text: result.text,
                                     languageCode: languageCode ?? result.languageCode,
                                     detectedLanguageCode: result.languageCode)
    }
}
