import Foundation
import Testing
@testable import KeyVox

struct AudioCaptureClassificationTests {
    @Test
    func classifyMarksAbsoluteSilenceAndLikelySilenceForLongQuietCapture() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 3)
        let speechOnly = snapshot

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 3.0,
            maxActiveSignalRunDuration: 0
        )

        #expect(result.isAbsoluteSilence)
        #expect(!result.hadActiveSignal)
        #expect(result.shouldRejectLikelySilence)
        #expect(!result.isLongTrueSilence)
    }

    @Test
    func classifyMarksLongTrueSilenceAfterFiveSeconds() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 6)
        let speechOnly = snapshot

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 6.0,
            maxActiveSignalRunDuration: 0
        )

        #expect(result.isLongTrueSilence)
        #expect(result.silentWindowRatio >= AudioSilenceGatePolicy.trueSilenceMinimumWindowRatio)
    }

    @Test
    func classifyDetectsActiveSignalFromRunDuration() {
        let snapshot = Array(repeating: Float(0), count: 16_000 * 6)
        let speechOnly = snapshot

        let result = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: 6.0,
            maxActiveSignalRunDuration: AudioSilenceGatePolicy.minimumActiveSignalRunDuration + 0.01
        )

        #expect(result.hadActiveSignal)
        #expect(!result.isLongTrueSilence)
    }
}
