import Foundation
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

        XCTAssertEqual(finalBufferedCount, initialFrames.count + lateFrames.count)
        XCTAssertEqual(returnedFrames.count, finalBufferedCount)
    }
}
