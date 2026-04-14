import Foundation
import AVFoundation
import XCTest
@testable import KeyVox

final class AudioRecorderStopRecordingTests: XCTestCase {
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
        let expectedTrailingPadFrames = Int(
            (recorder.transcriptionTrailingSilenceDuration * recorder.outputFormat.sampleRate).rounded()
        )

        XCTAssertEqual(finalBufferedCount, initialFrames.count + lateFrames.count)
        XCTAssertEqual(returnedFrames.count, finalBufferedCount + expectedTrailingPadFrames)
        XCTAssertEqual(Array(returnedFrames.suffix(expectedTrailingPadFrames)), Array(repeating: 0, count: expectedTrailingPadFrames))
    }

    func testStopRecordingIncludesTailFramesDeliveredShortlyAfterStopRequest() {
        let recorder = AudioRecorder()
        recorder.captureStartedAt = Date()
        recorder.isRecording = true
        recorder.stopCaptureTailDuration = 0.06

        let initialFrames = Array(repeating: Float(0.2), count: 1_600)
        let tailFrames = Array(repeating: Float(0.2), count: 800)

        recorder.audioDataQueue.sync {
            recorder.audioData = initialFrames
        }

        recorder.captureQueue.asyncAfter(deadline: .now() + 0.02) {
            recorder.audioDataQueue.sync {
                recorder.audioData.append(contentsOf: tailFrames)
            }
        }

        let stopFinished = expectation(description: "stop finished with tail frames")
        var returnedFrames: [Float] = []
        recorder.stopRecording { frames in
            returnedFrames = frames
            stopFinished.fulfill()
        }

        wait(for: [stopFinished], timeout: 1.0)

        let finalBufferedCount = recorder.audioDataQueue.sync {
            recorder.audioData.count
        }
        let expectedTrailingPadFrames = Int(
            (recorder.transcriptionTrailingSilenceDuration * recorder.outputFormat.sampleRate).rounded()
        )

        XCTAssertEqual(finalBufferedCount, initialFrames.count + tailFrames.count)
        XCTAssertEqual(returnedFrames.count, finalBufferedCount + expectedTrailingPadFrames)
        XCTAssertEqual(Array(returnedFrames.suffix(expectedTrailingPadFrames)), Array(repeating: 0, count: expectedTrailingPadFrames))
    }

    func testOutputFramesForStoppedCaptureAppendsTranscriptionSilencePad() {
        let recorder = AudioRecorder()
        recorder.captureStartedAt = Date().addingTimeInterval(-0.2)

        let samples = Array(repeating: Float(0.2), count: 1_600)
        recorder.audioDataQueue.sync {
            recorder.audioData = samples
        }

        let outputFrames = recorder.outputFramesForStoppedCapture()
        let expectedTrailingPadFrames = Int(
            (recorder.transcriptionTrailingSilenceDuration * recorder.outputFormat.sampleRate).rounded()
        )
        let expectedNormalizedFrames = Array(repeating: Float(0.6), count: samples.count)

        XCTAssertEqual(outputFrames.count, samples.count + expectedTrailingPadFrames)
        XCTAssertEqual(Array(outputFrames.prefix(samples.count)), expectedNormalizedFrames)
        XCTAssertEqual(Array(outputFrames.suffix(expectedTrailingPadFrames)), Array(repeating: 0, count: expectedTrailingPadFrames))
    }
}
