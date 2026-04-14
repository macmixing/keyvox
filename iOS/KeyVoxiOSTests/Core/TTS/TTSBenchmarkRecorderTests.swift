import Foundation
import KeyVoxTTS
import Testing
@testable import KeyVox_iOS

@MainActor
struct TTSBenchmarkRecorderTests {
    @Test func finishedRunCapturesMilestonesAndChunkMetrics() {
        var recordedDates = [
            Date(timeIntervalSince1970: 0.00),
            Date(timeIntervalSince1970: 0.10),
            Date(timeIntervalSince1970: 0.22),
            Date(timeIntervalSince1970: 0.31),
            Date(timeIntervalSince1970: 0.47),
            Date(timeIntervalSince1970: 0.60),
            Date(timeIntervalSince1970: 0.88),
            Date(timeIntervalSince1970: 1.91),
            Date(timeIntervalSince1970: 2.40),
            Date(timeIntervalSince1970: 2.95),
        ]
        let recorder = TTSBenchmarkRecorder(nowProvider: {
            recordedDates.removeFirst()
        })
        let request = makeRequest(text: "Benchmark this medium length sample for Theo.")

        recorder.beginRun(
            label: "Medium",
            request: request,
            voiceDisplayName: "Theo",
            fastModeEnabled: true
        )
        recorder.markEnginePrepared(for: request.id)
        recorder.markStreamCreated(for: request.id)
        recorder.recordFrame(
            KeyVoxTTSAudioFrame(
                samples: Array(repeating: 0.2, count: 4_800),
                frameIndex: 0,
                chunkIndex: 0,
                chunkCount: 2,
                isChunkFinalBatch: false,
                chunkDebugID: "chunk-0",
                estimatedRemainingSampleCount: 19_200
            ),
            for: request.id
        )
        recorder.recordFrame(
            KeyVoxTTSAudioFrame(
                samples: Array(repeating: 0.2, count: 7_200),
                frameIndex: 7,
                chunkIndex: 0,
                chunkCount: 2,
                isChunkFinalBatch: true,
                chunkDebugID: "chunk-0",
                estimatedRemainingSampleCount: 12_000,
                chunkGeneratedSampleCount: 24_000,
                chunkGenerationDurationSeconds: 0.45
            ),
            for: request.id
        )
        recorder.markPlaybackStarted(for: request.id)
        recorder.markBackgroundReady(for: request.id)
        recorder.markBackgroundStable(for: request.id)
        recorder.markReplayReady(for: request.id, totalSampleCount: 48_000)
        recorder.markFinished(for: request.id)

        let report = recorder.latestCompletedRun

        #expect(report?.label == "Medium")
        #expect(report?.fastModeEnabled == true)
        #expect(report?.wordCount == 7)
        #expect(report?.chunkCount == 2)
        #expect(report?.totalGeneratedSampleCount == 48_000)
        #expect(abs((report?.requestToEnginePreparedSeconds ?? 0) - 0.10) < 0.0001)
        #expect(abs((report?.requestToStreamCreatedSeconds ?? 0) - 0.22) < 0.0001)
        #expect(abs((report?.requestToFirstFrameSeconds ?? 0) - 0.31) < 0.0001)
        #expect(abs((report?.requestToFirstAudioSeconds ?? 0) - 0.60) < 0.0001)
        #expect(abs((report?.requestToFirstChunkCompletedSeconds ?? 0) - 0.47) < 0.0001)
        #expect(abs((report?.requestToBackgroundReadySeconds ?? 0) - 0.88) < 0.0001)
        #expect(abs((report?.requestToBackgroundStableSeconds ?? 0) - 1.91) < 0.0001)
        #expect(abs((report?.requestToReplayReadySeconds ?? 0) - 2.40) < 0.0001)
        #expect(abs((report?.requestToPlaybackFinishedSeconds ?? 0) - 2.95) < 0.0001)
        #expect(report?.chunkReports.count == 1)
        #expect(report?.chunkReports.first?.generatedSampleCount == 24_000)
        #expect(abs((report?.chunkReports.first?.generationRealtimeFactor ?? 0) - 2.2222222222222223) < 0.0001)
        #expect(report?.formattedSummary.contains("Time to first audio: 600.0 ms") == true)
    }

    @Test func failedRunPreservesErrorMessage() {
        var recordedDates = [
            Date(timeIntervalSince1970: 0.00),
            Date(timeIntervalSince1970: 0.14),
        ]
        let recorder = TTSBenchmarkRecorder(nowProvider: {
            recordedDates.removeFirst()
        })
        let request = makeRequest(text: "A shorter benchmark sample.")

        recorder.beginRun(
            label: "Short",
            request: request,
            voiceDisplayName: "Theo",
            fastModeEnabled: false
        )
        recorder.markFailed(for: request.id, message: "Synthetic failure")

        let report = recorder.latestCompletedRun

        #expect(report?.outcome == .failed)
        #expect(report?.errorMessage == "Synthetic failure")
        #expect(abs((report?.requestToPlaybackFinishedSeconds ?? 0) - 0.14) < 0.0001)
    }

    private func makeRequest(text: String) -> KeyVox_iOS.KeyVoxTTSRequest {
        KeyVox_iOS.KeyVoxTTSRequest(
            id: UUID(),
            text: text,
            createdAt: 0,
            sourceSurface: KeyVox_iOS.KeyVoxTTSRequestSourceSurface.app,
            voiceID: AppSettingsStore.TTSVoice.alba.rawValue,
            kind: KeyVox_iOS.KeyVoxTTSRequestKind.speakClipboardText
        )
    }
}
