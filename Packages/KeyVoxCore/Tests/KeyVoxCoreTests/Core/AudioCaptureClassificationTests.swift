import Foundation
import XCTest
@testable import KeyVoxCore

final class AudioCaptureClassificationTests: XCTestCase {
    func testClassifyMarksAbsoluteSilenceLikelySilenceAndLongTrueSilenceAtThreshold() {
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
        XCTAssertTrue(result.isLongTrueSilence)
    }

    func testClassifyMarksLongTrueSilenceAfterThreeSeconds() {
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
}
