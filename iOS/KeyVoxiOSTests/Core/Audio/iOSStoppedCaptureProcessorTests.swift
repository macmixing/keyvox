import Testing
import KeyVoxCore
@testable import KeyVox_iOS

struct iOSStoppedCaptureProcessorTests {
    @Test func preservesSpeechForNormalCapture() {
        let snapshot = Array(repeating: Float(0.2), count: 4_000)
        let result = iOSStoppedCaptureProcessor.process(
            snapshot: snapshot,
            captureDuration: 1.0,
            maxActiveSignalRunDuration: 0.5,
            gapRemovalRMSThreshold: 0.0023,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018,
            normalizationTargetPeak: 0.9,
            normalizationMaxGain: 3.0
        )

        #expect(result.classification.hadActiveSignal)
        #expect(!result.outputFrames.isEmpty)
    }

    @Test func rejectsLongTrueSilence() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 4)
        let result = iOSStoppedCaptureProcessor.process(
            snapshot: snapshot,
            captureDuration: 4.0,
            maxActiveSignalRunDuration: 0,
            gapRemovalRMSThreshold: 0.0023,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018,
            normalizationTargetPeak: 0.9,
            normalizationMaxGain: 3.0
        )

        #expect(result.classification.isLongTrueSilence)
        #expect(result.outputFrames.isEmpty)
    }

    @Test func rejectsLowEnergyLikelySilence() {
        let snapshot = Array(repeating: Float(0.0005), count: 16_000 * 3)
        let result = iOSStoppedCaptureProcessor.process(
            snapshot: snapshot,
            captureDuration: 3.0,
            maxActiveSignalRunDuration: 0,
            gapRemovalRMSThreshold: 0.0023,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018,
            normalizationTargetPeak: 0.9,
            normalizationMaxGain: 3.0
        )

        #expect(result.classification.shouldRejectLikelySilence)
        #expect(result.outputFrames.isEmpty)
    }
}
