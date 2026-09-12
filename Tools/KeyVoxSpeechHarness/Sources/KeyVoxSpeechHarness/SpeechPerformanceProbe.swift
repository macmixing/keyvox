import Foundation
import KeyVoxCore

/// Measures repeated production-service inference and text processing independently.
enum SpeechPerformanceProbe {
    enum Failure: Error { case invalidRepeatCount, missingModel, missingSpeech, changedOutput }

    private struct Run: Encodable {
        let providerMilliseconds: Double
        let postProcessingMilliseconds: Double
        let output: String
    }

    private struct Report: Encodable {
        let modelWarmupMilliseconds: Double
        let textPreparationMilliseconds: Double
        let runs: [Run]
    }

    @MainActor
    static func run(modelPath: String, audioPath: String, repeats: Int) async throws {
        guard (1...10).contains(repeats) else { throw Failure.invalidRepeatCount }
        let service = WhisperService(modelPathResolver: { modelPath })
        guard service.isModelReady else { throw Failure.missingModel }
        defer { service.unloadModel() }
        let warmupStart = ContinuousClock.now
        service.warmup()
        let modelWarmup = elapsed(since: warmupStart)
        let preparationStart = ContinuousClock.now
        let processor = TranscriptionPostProcessor()
        let dictionary = await HarnessDictionary.load()
        let preparation = elapsed(since: preparationStart)
        var runs: [Run] = []
        for _ in 0..<repeats {
            let providerStart = ContinuousClock.now
            let result: TranscriptionProviderResult? = await withCheckedContinuation { continuation in
                service.transcribe(audioURL: URL(fileURLWithPath: audioPath)) {
                    continuation.resume(returning: $0)
                }
            }
            let provider = elapsed(since: providerStart)
            guard let result, !result.text.isEmpty else { throw Failure.missingSpeech }
            let processingStart = ContinuousClock.now
            let output = await processor.processAsync(result.text, dictionaryEntries: dictionary.entries,
                renderMode: .multiline, listFormattingEnabled: true, languageCode: result.languageCode)
            let processing = elapsed(since: processingStart)
            guard !output.isEmpty else { throw Failure.missingSpeech }
            if let first = runs.first, first.output != output { throw Failure.changedOutput }
            runs.append(Run(providerMilliseconds: provider, postProcessingMilliseconds: processing, output: output))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let report = Report(modelWarmupMilliseconds: modelWarmup,
                            textPreparationMilliseconds: preparation, runs: runs)
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }

    private static func elapsed(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now).components
        return Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1_000_000_000_000_000
    }
}
