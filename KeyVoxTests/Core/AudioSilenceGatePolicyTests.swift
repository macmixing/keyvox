import Foundation
import XCTest
@testable import KeyVox

final class AudioSilenceGatePolicyTests: XCTestCase {
    func testRejectsLongCaptureWithoutActiveSignalWhenRMSIsLow() {
        XCTAssertTrue(
            AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 2.5,
                hadActiveSignal: false,
                silentWindowRatio: 1.0,
                speechRMS: 0.001
            )
        )
    }

    func testAllowsLongCaptureWithoutActiveSignalWhenRMSIsHigher() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 2.5,
                hadActiveSignal: false,
                silentWindowRatio: 1.0,
                speechRMS: 0.0032
            )
        )
    }

    func testAllowsShortCaptureWithoutActiveSignalEvenWhenRMSIsLow() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 1.0,
                hadActiveSignal: false,
                silentWindowRatio: 1.0,
                speechRMS: 0.001
            )
        )
    }

    func testRejectsLongCaptureWhenActiveSignalWasObservedButMostlySilent() {
        XCTAssertTrue(
            AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 4.0,
                hadActiveSignal: true,
                silentWindowRatio: 0.95,
                speechRMS: 0.0004
            )
        )
    }

    func testAllowsLongCaptureWhenActiveSignalWasObservedAndSilenceRatioIsLower() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 4.0,
                hadActiveSignal: true,
                silentWindowRatio: 0.7,
                speechRMS: 0.0004
            )
        )
    }

    func testFlagsLongTrueSilenceWhenDurationAndRatioMatch() {
        XCTAssertTrue(
            AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 5.5,
                hadActiveSignal: false,
                silentWindowRatio: 0.99
            )
        )
    }

    func testFlagsLongTrueSilenceWithBriefSpikeStillAboveRatioThreshold() {
        let samples = makeSamples(windowCount: 100, noisyWindowIndexes: Set([42]), noisyAmplitude: 0.0022)
        let ratio = AudioSilenceGatePolicy.trueSilenceWindowRatio(for: samples)
        XCTAssertTrue(ratio >= AudioSilenceGatePolicy.trueSilenceMinimumWindowRatio)
        XCTAssertTrue(
            AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 6.0,
                hadActiveSignal: false,
                silentWindowRatio: ratio
            )
        )
    }

    func testFlagsLongTrueSilenceWhenActiveSignalWasObservedAndSilenceIsNearTotal() {
        XCTAssertTrue(
            AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 8.0,
                hadActiveSignal: true,
                silentWindowRatio: 1.0
            )
        )
    }

    func testDoesNotFlagLongTrueSilenceWhenActiveSignalWasObservedAndSilenceRatioIsNotExtreme() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 8.0,
                hadActiveSignal: true,
                silentWindowRatio: 0.95
            )
        )
    }

    func testDoesNotFlagLongTrueSilenceWhenDurationIsBelowThreshold() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 4.9,
                hadActiveSignal: false,
                silentWindowRatio: 1.0
            )
        )
    }

    func testRequiresSustainedActiveSignalRunToMarkCaptureAsActive() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.hadActiveSpeechEvidence(
                maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration - 0.01
            )
        )
        XCTAssertTrue(
            AudioSilenceGatePolicy.hadActiveSpeechEvidence(
                maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration + 0.01
            )
        )
    }

    func testThresholdScaleTracksInputVolumeAndStaysClamped() {
        let lowScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: 0.0)
        let mediumScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: 0.5)
        let highScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: 1.0)

        XCTAssertTrue(lowScale == AudioSilenceGatePolicy.thresholdScaleMinimum)
        XCTAssertTrue(mediumScale == 1.0)
        XCTAssertTrue(highScale == AudioSilenceGatePolicy.thresholdScaleMaximum)
    }

    func testRejectsNoiseDominatedCaptureWhenSpeechRMSIsNearAmbientFloor() {
        XCTAssertTrue(
            AudioSilenceGatePolicy.shouldRejectNoiseDominatedCapture(
                hadActiveSignal: true,
                speechRMS: 0.0042,
                ambientFloorRMS: 0.004
            )
        )
    }

    func testKeepsCaptureWhenSpeechRMSSeparatesFromAmbientFloor() {
        XCTAssertTrue(
            !AudioSilenceGatePolicy.shouldRejectNoiseDominatedCapture(
                hadActiveSignal: false,
                speechRMS: 0.0075,
                ambientFloorRMS: 0.004
            )
        )
    }

    private func makeSamples(
        windowCount: Int,
        noisyWindowIndexes: Set<Int>,
        noisyAmplitude: Float
    ) -> [Float] {
        let windowSize = AudioSilenceGatePolicy.trueSilenceWindowSize
        var samples = Array(repeating: Float(0), count: windowCount * windowSize)

        for index in noisyWindowIndexes {
            guard index >= 0 && index < windowCount else { continue }
            let start = index * windowSize
            let end = start + windowSize
            for sampleIndex in start..<end {
                samples[sampleIndex] = noisyAmplitude
            }
        }

        return samples
    }
}
