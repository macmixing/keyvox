import Combine
import Foundation
import KeyVoxTTS

@MainActor
final class TTSBenchmarkRecorder: ObservableObject {
    @Published private(set) var activeLabel: String?
    @Published private(set) var latestCompletedRun: TTSBenchmarkRunReport?
    @Published private(set) var recentRuns: [TTSBenchmarkRunReport] = []

    private let nowProvider: () -> Date
    private var activeRun: ActiveRun?

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
    }

    var isRunning: Bool {
        activeRun != nil
    }

    func beginRun(
        label: String,
        request: KeyVoxTTSRequest,
        voiceDisplayName: String,
        fastModeEnabled: Bool
    ) {
        activeRun = ActiveRun(
            label: label,
            request: request,
            voiceDisplayName: voiceDisplayName,
            fastModeEnabled: fastModeEnabled,
            startedAt: nowProvider()
        )
        activeLabel = label
    }

    func markEnginePrepared(for requestID: UUID) {
        guard activeRun?.request.id == requestID else { return }
        activeRun?.enginePreparedAt = nowProvider()
    }

    func markStreamCreated(for requestID: UUID) {
        guard activeRun?.request.id == requestID else { return }
        activeRun?.streamCreatedAt = nowProvider()
    }

    func recordFrame(_ frame: KeyVoxTTSAudioFrame, for requestID: UUID) {
        guard var run = activeRun, run.request.id == requestID else { return }

        run.chunkCount = max(run.chunkCount, frame.chunkCount)
        run.totalGeneratedSampleCount += frame.sampleCount
        run.chunkSampleCounts[frame.chunkIndex, default: 0] += frame.sampleCount

        if run.firstFrameAt == nil, frame.sampleCount > 0 {
            run.firstFrameAt = nowProvider()
        }

        if frame.isChunkFinalBatch {
            if run.firstChunkCompletedAt == nil {
                run.firstChunkCompletedAt = nowProvider()
            }
            let generatedSampleCount = frame.chunkGeneratedSampleCount ?? run.chunkSampleCounts[frame.chunkIndex, default: 0]
            run.chunkReports[frame.chunkIndex] = TTSBenchmarkChunkReport(
                chunkIndex: frame.chunkIndex,
                chunkCount: frame.chunkCount,
                generatedSampleCount: generatedSampleCount,
                generationDurationSeconds: frame.chunkGenerationDurationSeconds
            )
        }

        activeRun = run
    }

    func markPlaybackStarted(for requestID: UUID) {
        guard activeRun?.request.id == requestID else { return }
        activeRun?.playbackStartedAt = nowProvider()
    }

    func markBackgroundReady(for requestID: UUID) {
        guard activeRun?.request.id == requestID else { return }
        guard activeRun?.backgroundReadyAt == nil else { return }
        activeRun?.backgroundReadyAt = nowProvider()
    }

    func markBackgroundStable(for requestID: UUID) {
        guard activeRun?.request.id == requestID else { return }
        guard activeRun?.backgroundStableAt == nil else { return }
        activeRun?.backgroundStableAt = nowProvider()
    }

    func markReplayReady(for requestID: UUID, totalSampleCount: Int) {
        guard var run = activeRun, run.request.id == requestID else { return }
        if run.replayReadyAt == nil {
            run.replayReadyAt = nowProvider()
        }
        run.totalGeneratedSampleCount = max(run.totalGeneratedSampleCount, totalSampleCount)
        activeRun = run
    }

    func markFinished(for requestID: UUID) {
        finalizeRun(for: requestID, outcome: .finished, errorMessage: nil)
    }

    func markFailed(for requestID: UUID, message: String) {
        finalizeRun(for: requestID, outcome: .failed, errorMessage: message)
    }

    func markCancelled(for requestID: UUID) {
        finalizeRun(for: requestID, outcome: .cancelled, errorMessage: nil)
    }

    func clearReports() {
        latestCompletedRun = nil
        recentRuns.removeAll(keepingCapacity: false)
    }

    private func finalizeRun(for requestID: UUID, outcome: TTSBenchmarkOutcome, errorMessage: String?) {
        guard let run = activeRun, run.request.id == requestID else { return }

        let finishedAt = nowProvider()
        let report = TTSBenchmarkRunReport(
            id: run.request.id,
            label: run.label,
            recordedAt: finishedAt,
            voiceID: run.request.voiceID,
            voiceDisplayName: run.voiceDisplayName,
            fastModeEnabled: run.fastModeEnabled,
            sourceSurface: run.request.sourceSurface,
            characterCount: run.characterCount,
            wordCount: run.wordCount,
            textPreview: run.textPreview,
            chunkCount: max(run.chunkCount, run.chunkReports.count),
            totalGeneratedSampleCount: run.totalGeneratedSampleCount,
            outcome: outcome,
            errorMessage: errorMessage,
            requestToEnginePreparedSeconds: run.elapsedSeconds(until: run.enginePreparedAt),
            requestToStreamCreatedSeconds: run.elapsedSeconds(until: run.streamCreatedAt),
            requestToFirstFrameSeconds: run.elapsedSeconds(until: run.firstFrameAt),
            requestToPlaybackStartedSeconds: run.elapsedSeconds(until: run.playbackStartedAt),
            requestToFirstChunkCompletedSeconds: run.elapsedSeconds(until: run.firstChunkCompletedAt),
            requestToBackgroundReadySeconds: run.elapsedSeconds(until: run.backgroundReadyAt),
            requestToBackgroundStableSeconds: run.elapsedSeconds(until: run.backgroundStableAt),
            requestToReplayReadySeconds: run.elapsedSeconds(until: run.replayReadyAt),
            requestToPlaybackFinishedSeconds: run.startedAt <= finishedAt
                ? finishedAt.timeIntervalSince(run.startedAt)
                : nil,
            chunkReports: run.chunkReports.values.sorted { $0.chunkIndex < $1.chunkIndex }
        )

        latestCompletedRun = report
        recentRuns.insert(report, at: 0)
        if recentRuns.count > 6 {
            recentRuns.removeLast(recentRuns.count - 6)
        }
        activeRun = nil
        activeLabel = nil
    }
}

private struct ActiveRun {
    let label: String
    let request: KeyVoxTTSRequest
    let voiceDisplayName: String
    let fastModeEnabled: Bool
    let startedAt: Date
    let characterCount: Int
    let wordCount: Int
    let textPreview: String

    var chunkCount = 0
    var totalGeneratedSampleCount = 0
    var enginePreparedAt: Date?
    var streamCreatedAt: Date?
    var firstFrameAt: Date?
    var playbackStartedAt: Date?
    var firstChunkCompletedAt: Date?
    var backgroundReadyAt: Date?
    var backgroundStableAt: Date?
    var replayReadyAt: Date?
    var chunkSampleCounts: [Int: Int] = [:]
    var chunkReports: [Int: TTSBenchmarkChunkReport] = [:]

    init(
        label: String,
        request: KeyVoxTTSRequest,
        voiceDisplayName: String,
        fastModeEnabled: Bool,
        startedAt: Date
    ) {
        self.label = label
        self.request = request
        self.voiceDisplayName = voiceDisplayName
        self.fastModeEnabled = fastModeEnabled
        self.startedAt = startedAt
        characterCount = request.trimmedText.count
        wordCount = request.trimmedText.split(whereSeparator: { $0.isWhitespace }).count
        let normalizedPreview = request.trimmedText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        textPreview = String(normalizedPreview.prefix(100))
    }

    func elapsedSeconds(until date: Date?) -> Double? {
        guard let date, startedAt <= date else { return nil }
        return date.timeIntervalSince(startedAt)
    }
}
