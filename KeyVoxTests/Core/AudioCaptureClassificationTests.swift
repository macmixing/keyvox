import Foundation
import XCTest
@testable import KeyVox

final class AudioCaptureClassificationTests: XCTestCase {
    func testClassifyMarksAbsoluteSilenceAndLikelySilenceForLongQuietCapture() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 3)
        let speechOnly = snapshot

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 3.0,
            maxActiveSignalRunDuration: 0
        )

        XCTAssertTrue(result.isAbsoluteSilence)
        XCTAssertTrue(!result.hadActiveSignal)
        XCTAssertTrue(result.shouldRejectLikelySilence)
        XCTAssertTrue(!result.isLongTrueSilence)
    }

    func testClassifyMarksLongTrueSilenceAfterFiveSeconds() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 6)
        let speechOnly = snapshot

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 6.0,
            maxActiveSignalRunDuration: 0
        )

        XCTAssertTrue(result.isLongTrueSilence)
        XCTAssertTrue(result.silentWindowRatio >= AudioSilenceGatePolicy.trueSilenceMinimumWindowRatio)
    }

    func testClassifyDetectsActiveSignalFromRunDuration() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 6)
        let speechOnly = snapshot

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 6.0,
            maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration + 0.01
        )

        XCTAssertTrue(result.hadActiveSignal)
        XCTAssertTrue(result.isLongTrueSilence)
        XCTAssertTrue(result.shouldRejectLikelySilence)
    }

    func testClassifyRejectsNoiseDominatedCaptureEvenWhenSilenceRatioIsLow() {
        let snapshot = Array(repeating: Float(0.004), count: 16_000 * 4)
        let speechOnly = Array(repeating: Float(0.0042), count: 16_000 * 2)

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 4.0,
            maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration + 0.01,
            trueSilenceWindowRMSThreshold: 0.0018
        )

        XCTAssertTrue(result.silentWindowRatio == 0)
        XCTAssertTrue(result.shouldRejectLikelySilence)
    }

    func testStopRecordingWaitsForQueuedCaptureWorkBeforeSnapshot() {
        let recorder = AudioRecorder()
        recorder.captureStartedAt = Date()
        recorder.isRecording = true

        let initialFrames = Array(repeating: Float(0.2), count: 1_600)
        let lateFrames = Array(repeating: Float(0.2), count: 800)

        recorder.audioDataQueue.sync {
            recorder.audioData = initialFrames
        }

        let startedBacklog = expectation(description: "capture backlog started")
        recorder.captureQueue.async {
            startedBacklog.fulfill()
            Thread.sleep(forTimeInterval: 0.05)
        }
        recorder.captureQueue.async {
            recorder.audioDataQueue.sync {
                recorder.audioData.append(contentsOf: lateFrames)
            }
        }

        wait(for: [startedBacklog], timeout: 1.0)

        let stopFinished = expectation(description: "stop finished")
        var returnedFrames: [Float] = []
        recorder.stopRecording { frames in
            returnedFrames = frames
            stopFinished.fulfill()
        }

        wait(for: [stopFinished], timeout: 1.0)

        let finalBufferedCount = recorder.audioDataQueue.sync {
            recorder.audioData.count
        }

        XCTAssertEqual(finalBufferedCount, initialFrames.count + lateFrames.count)
        XCTAssertEqual(returnedFrames.count, finalBufferedCount)
    }
}
