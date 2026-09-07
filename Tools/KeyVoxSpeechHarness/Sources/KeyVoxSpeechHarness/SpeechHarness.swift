import Foundation
import Dispatch
import KeyVoxVoiceActivity
import KeyVoxWhisper

@main
struct SpeechHarness {
    enum HarnessError: Error { case usage, vadInitialization, vadAnalysis }

    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard (1...4).contains(arguments.count) else {
            print("Usage: KeyVoxSpeechHarness whisper-model | vad <audio.f32le> | transcribe <model.bin> <audio.f32le> | pipeline <model.bin> <audio.f32le> [language-code] | file-pipeline <model.bin> <audio-file> [language-code] | parakeet-file-pipeline <model.gguf> <audio-file> [language-code] | process <text-file> [language-code] | dictionary-add <storage-directory> <phrase-file>")
            throw HarnessError.usage
        }
        switch arguments[0] {
        case "whisper-model" where arguments.count == 1:
            try WhisperModelReport.printArtifact()
        case "dictionary-add" where arguments.count == 3:
            try await HarnessDictionary.add(directory: arguments[1], phrasePath: arguments[2])
        case "vad" where arguments.count == 2:
            let frames = try PCMInput.read(arguments[1])
            guard let detector = VoiceActivityDetector() else { throw HarnessError.vadInitialization }
            guard let analysis = await detector.analyze(audioFrames: frames) else {
                throw HarnessError.vadAnalysis
            }
            print("samples=\(frames.count) probabilities=\(analysis.probabilities.count) speech=\(analysis.containsSpeech) segments=\(analysis.speechSegments.count)")
        case "transcribe" where arguments.count == 3:
            let frames = try PCMInput.read(arguments[2])
            let whisper = Whisper(fromFileURL: URL(fileURLWithPath: arguments[1]))
            let result = try await whisper.transcribeWithMetadata(audioFrames: frames)
            print("samples=\(frames.count) segments=\(result.segments.count)")
            print(result.segments.map(\.text).joined())
        case "pipeline" where arguments.count == 3 || arguments.count == 4:
            let frames = try PCMInput.read(arguments[2])
            let whisper = Whisper(fromFileURL: URL(fileURLWithPath: arguments[1]))
            let result = try await whisper.transcribeWithMetadata(audioFrames: frames)
            let language = arguments.count == 4 ? arguments[3] : result.detectedLanguageCode
            try await CoreProcessing.run(
                text: result.segments.map(\.text).joined(),
                languageCode: language,
                detectedLanguageCode: result.detectedLanguageCode
            )
        case "file-pipeline" where arguments.count == 3 || arguments.count == 4:
            try await AudioFilePipeline.run(modelPath: arguments[1], audioPath: arguments[2],
                                            languageCode: arguments.count == 4 ? arguments[3] : nil)
        case "parakeet-file-pipeline" where arguments.count == 3 || arguments.count == 4:
            try await ParakeetFilePipeline.run(modelPath: arguments[1], audioPath: arguments[2],
                                               languageCode: arguments.count == 4 ? arguments[3] : nil)
        case "process" where arguments.count == 2 || arguments.count == 3:
            let text = try String(contentsOfFile: arguments[1], encoding: .utf8)
            try await CoreProcessing.run(text: text, languageCode: arguments.count == 3 ? arguments[2] : nil)
        default:
            throw HarnessError.usage
        }
    }
}
