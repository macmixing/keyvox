import Foundation
import KeyVoxVoiceActivity
import KeyVoxWhisper

@main
struct SpeechHarness {
    enum HarnessError: Error { case usage, vadInitialization, vadAnalysis }

    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 || arguments.count == 3 else {
            print("Usage: KeyVoxSpeechHarness vad <audio.f32le> | transcribe <model.bin> <audio.f32le>")
            throw HarnessError.usage
        }
        switch arguments[0] {
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
        default:
            throw HarnessError.usage
        }
    }
}
