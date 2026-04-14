import Combine
import Foundation

enum TTSBenchmarkFormatter {
    static func summary(for report: TTSBenchmarkRunReport) -> String {
        var lines: [String] = []
        lines.append("TTS benchmark: \(report.label)")
        lines.append("Outcome: \(report.outcome.rawValue)")
        lines.append("Voice: \(report.voiceDisplayName) (\(report.voiceID))")
        lines.append("Fast mode: \(report.fastModeEnabled ? "on" : "off")")
        lines.append("Source: \(report.sourceSurface.rawValue)")
        lines.append("Words: \(report.wordCount)")
        lines.append("Characters: \(report.characterCount)")
        lines.append("Chunks: \(report.chunkCount)")
        lines.append("Generated audio: \(durationString(for: report.generatedAudioDurationSeconds))")
        lines.append("Preview: \(report.textPreview)")
        lines.append("Engine prepared: \(metricString(report.requestToEnginePreparedSeconds))")
        lines.append("Stream created: \(metricString(report.requestToStreamCreatedSeconds))")
        lines.append("First frame: \(metricString(report.requestToFirstFrameSeconds))")
        lines.append("Time to first audio: \(metricString(report.requestToFirstAudioSeconds))")
        lines.append("First chunk complete: \(metricString(report.requestToFirstChunkCompletedSeconds))")
        lines.append("Background ready: \(metricString(report.requestToBackgroundReadySeconds))")
        lines.append("Background stable: \(metricString(report.requestToBackgroundStableSeconds))")
        lines.append("Replay ready: \(metricString(report.requestToReplayReadySeconds))")
        lines.append("Playback finished: \(metricString(report.requestToPlaybackFinishedSeconds))")
        lines.append("Overall realtime factor: \(ratioString(report.overallGenerationRealtimeFactor))")
        lines.append("Words/sec to first audio: \(rateString(report.firstAudioWordsPerSecond, unit: "w/s"))")
        lines.append("Words/sec to replay ready: \(rateString(report.replayReadyWordsPerSecond, unit: "w/s"))")
        lines.append("Chars/sec to replay ready: \(rateString(report.replayReadyCharactersPerSecond, unit: "c/s"))")

        if let errorMessage = report.errorMessage {
            lines.append("Error: \(errorMessage)")
        }

        if report.chunkReports.isEmpty == false {
            lines.append("Chunk metrics:")
            for chunk in report.chunkReports {
                lines.append(
                    "Chunk \(chunk.chunkIndex + 1)/\(chunk.chunkCount): generation=\(metricString(chunk.generationDurationSeconds)) audio=\(durationString(for: chunk.generatedAudioDurationSeconds)) realtime=\(ratioString(chunk.generationRealtimeFactor))"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    static func metricString(_ seconds: Double?) -> String {
        guard let seconds else { return "n/a" }
        return millisecondsString(for: seconds)
    }

    static func durationString(for seconds: Double) -> String {
        guard seconds >= 1 else {
            return millisecondsString(for: seconds)
        }
        return String(format: "%.2f s", seconds)
    }

    static func millisecondsString(for seconds: Double) -> String {
        String(format: "%.1f ms", seconds * 1_000.0)
    }

    static func ratioString(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2fx", value)
    }

    static func rateString(_ value: Double?, unit: String) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f %@", value, unit)
    }
}
