import Combine
import Foundation

enum TTSBenchmarkOutcome: String, Equatable {
    case finished
    case failed
    case cancelled
}

struct TTSBenchmarkChunkReport: Identifiable, Equatable {
    let chunkIndex: Int
    let chunkCount: Int
    let generatedSampleCount: Int
    let generationDurationSeconds: Double?

    var id: Int { chunkIndex }

    var generatedAudioDurationSeconds: Double {
        Double(generatedSampleCount) / 24_000.0
    }

    var generationRealtimeFactor: Double? {
        guard let generationDurationSeconds, generationDurationSeconds > 0 else { return nil }
        return generatedAudioDurationSeconds / generationDurationSeconds
    }
}

struct TTSBenchmarkRunReport: Identifiable, Equatable {
    let id: UUID
    let label: String
    let recordedAt: Date
    let voiceID: String
    let voiceDisplayName: String
    let fastModeEnabled: Bool
    let sourceSurface: KeyVoxTTSRequestSourceSurface
    let characterCount: Int
    let wordCount: Int
    let textPreview: String
    let chunkCount: Int
    let totalGeneratedSampleCount: Int
    let outcome: TTSBenchmarkOutcome
    let errorMessage: String?
    let requestToEnginePreparedSeconds: Double?
    let requestToStreamCreatedSeconds: Double?
    let requestToFirstFrameSeconds: Double?
    let requestToPlaybackStartedSeconds: Double?
    let requestToFirstChunkCompletedSeconds: Double?
    let requestToBackgroundReadySeconds: Double?
    let requestToBackgroundStableSeconds: Double?
    let requestToReplayReadySeconds: Double?
    let requestToPlaybackFinishedSeconds: Double?
    let chunkReports: [TTSBenchmarkChunkReport]

    var generatedAudioDurationSeconds: Double {
        Double(totalGeneratedSampleCount) / 24_000.0
    }

    var requestToFirstAudioSeconds: Double? {
        requestToPlaybackStartedSeconds
    }

    var overallGenerationRealtimeFactor: Double? {
        guard let requestToReplayReadySeconds, requestToReplayReadySeconds > 0 else { return nil }
        return generatedAudioDurationSeconds / requestToReplayReadySeconds
    }

    var firstAudioWordsPerSecond: Double? {
        guard let requestToFirstAudioSeconds, requestToFirstAudioSeconds > 0 else { return nil }
        return Double(wordCount) / requestToFirstAudioSeconds
    }

    var replayReadyWordsPerSecond: Double? {
        guard let requestToReplayReadySeconds, requestToReplayReadySeconds > 0 else { return nil }
        return Double(wordCount) / requestToReplayReadySeconds
    }

    var replayReadyCharactersPerSecond: Double? {
        guard let requestToReplayReadySeconds, requestToReplayReadySeconds > 0 else { return nil }
        return Double(characterCount) / requestToReplayReadySeconds
    }

    var formattedSummary: String {
        TTSBenchmarkFormatter.summary(for: self)
    }
}
