import Foundation
import KeyVoxCore

struct iOSStoppedCapture {
    let snapshot: [Float]
    let outputFrames: [Float]
    let classification: AudioCaptureClassification
    let captureDuration: TimeInterval
    let maxActiveSignalRunDuration: TimeInterval
}

enum iOSStoppedCaptureProcessor {
    static func process(
        snapshot: [Float],
        captureDuration: TimeInterval,
        maxActiveSignalRunDuration: TimeInterval,
        gapRemovalRMSThreshold: Float,
        lowConfidenceRMSCutoff: Float,
        trueSilenceWindowRMSThreshold: Float,
        normalizationTargetPeak: Float,
        normalizationMaxGain: Float
    ) -> iOSStoppedCapture {
        let speechOnly = AudioPostProcessing.removeInternalGaps(
            from: snapshot,
            gapRemovalRMSThreshold: gapRemovalRMSThreshold
        )
        let classification = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: maxActiveSignalRunDuration,
            lowConfidenceRMSCutoff: lowConfidenceRMSCutoff,
            trueSilenceWindowRMSThreshold: trueSilenceWindowRMSThreshold
        )

        let outputFrames: [Float]
        if classification.isLongTrueSilence || classification.shouldRejectLikelySilence {
            outputFrames = []
        } else {
            outputFrames = AudioPostProcessing.normalizeForTranscription(
                snapshot,
                targetPeak: normalizationTargetPeak,
                maxGain: normalizationMaxGain
            )
        }

        return iOSStoppedCapture(
            snapshot: snapshot,
            outputFrames: outputFrames,
            classification: classification,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: maxActiveSignalRunDuration
        )
    }
}
