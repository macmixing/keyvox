import Foundation
import Testing
@testable import KeyVox

struct AudioSilenceGatePolicyTests {
    @Test
    func rejectsLongCaptureWithoutActiveSignalWhenRMSIsLow() {
        #expect(
            AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 2.5,
                hadActiveSignal: false,
                silentWindowRatio: 1.0,
                speechRMS: 0.001
            )
        )
    }

    @Test
    func allowsLongCaptureWithoutActiveSignalWhenRMSIsHigher() {
        #expect(
            !AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 2.5,
                hadActiveSignal: false,
                silentWindowRatio: 1.0,
                speechRMS: 0.0032
            )
        )
    }

    @Test
    func allowsShortCaptureWithoutActiveSignalEvenWhenRMSIsLow() {
        #expect(
            !AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 1.0,
                hadActiveSignal: false,
                silentWindowRatio: 1.0,
                speechRMS: 0.001
            )
        )
    }

    @Test
    func rejectsLongCaptureWhenActiveSignalWasObservedButMostlySilent() {
        #expect(
            AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 4.0,
                hadActiveSignal: true,
                silentWindowRatio: 0.95,
                speechRMS: 0.0004
            )
        )
    }

    @Test
    func allowsLongCaptureWhenActiveSignalWasObservedAndSilenceRatioIsLower() {
        #expect(
            !AudioSilenceGatePolicy.shouldRejectLikelySilence(
                captureDuration: 4.0,
                hadActiveSignal: true,
                silentWindowRatio: 0.7,
                speechRMS: 0.0004
            )
        )
    }

    @Test
    func flagsLongTrueSilenceWhenDurationAndRatioMatch() {
        #expect(
            AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 5.5,
                hadActiveSignal: false,
                silentWindowRatio: 0.99
            )
        )
    }

    @Test
    func flagsLongTrueSilenceWithBriefSpikeStillAboveRatioThreshold() {
        let samples = makeSamples(windowCount: 100, noisyWindowIndexes: Set([42]), noisyAmplitude: 0.0022)
        let ratio = AudioSilenceGatePolicy.trueSilenceWindowRatio(for: samples)
        #expect(ratio >= AudioSilenceGatePolicy.trueSilenceMinimumWindowRatio)
        #expect(
            AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 6.0,
                hadActiveSignal: false,
                silentWindowRatio: ratio
            )
        )
    }

    @Test
    func flagsLongTrueSilenceWhenActiveSignalWasObservedAndSilenceIsNearTotal() {
        #expect(
            AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 8.0,
                hadActiveSignal: true,
                silentWindowRatio: 1.0
            )
        )
    }

    @Test
    func doesNotFlagLongTrueSilenceWhenActiveSignalWasObservedAndSilenceRatioIsNotExtreme() {
        #expect(
            !AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 8.0,
                hadActiveSignal: true,
                silentWindowRatio: 0.95
            )
        )
    }

    @Test
    func doesNotFlagLongTrueSilenceWhenDurationIsBelowThreshold() {
        #expect(
            !AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
                captureDuration: 4.9,
                hadActiveSignal: false,
                silentWindowRatio: 1.0
            )
        )
    }

    @Test
    func requiresSustainedActiveSignalRunToMarkCaptureAsActive() {
        #expect(
            !AudioSilenceGatePolicy.hadActiveSpeechEvidence(
                maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration - 0.01
            )
        )
        #expect(
            AudioSilenceGatePolicy.hadActiveSpeechEvidence(
                maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration + 0.01
            )
        )
    }

    @Test
    func thresholdScaleTracksInputVolumeAndStaysClamped() {
        let lowScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: 0.0)
        let mediumScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: 0.5)
        let highScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: 1.0)

        #expect(lowScale == AudioSilenceGatePolicy.thresholdScaleMinimum)
        #expect(mediumScale == 1.0)
        #expect(highScale == AudioSilenceGatePolicy.thresholdScaleMaximum)
    }

    @Test
    func rejectsNoiseDominatedCaptureWhenSpeechRMSIsNearAmbientFloor() {
        #expect(
            AudioSilenceGatePolicy.shouldRejectNoiseDominatedCapture(
                hadActiveSignal: true,
                speechRMS: 0.0042,
                ambientFloorRMS: 0.004
            )
        )
    }

    @Test
    func keepsCaptureWhenSpeechRMSSeparatesFromAmbientFloor() {
        #expect(
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
