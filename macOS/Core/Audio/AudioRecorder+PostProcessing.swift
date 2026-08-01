import Foundation
import KeyVoxCore

extension AudioRecorder {
    func outputFramesForStoppedCapture() -> [Float] {
        // Preserve stop pipeline contract:
        // 1) snapshot raw audio
        // 2) run gap removal / silence rejection
        // 3) normalize loudness
        // 4) return processed frames
        let snapshot: [Float] = audioDataQueue.sync { audioData }
        let speechOnly = AudioPostProcessing.removeInternalGaps(
            from: snapshot,
            gapRemovalRMSThreshold: sessionGapRemovalRMSThreshold
        )
        let captureDuration = Date().timeIntervalSince(captureStartedAt)
        lastCaptureDuration = captureDuration
        let classification = AudioCaptureClassifier.classify(
            snapshot: snapshot,
            speechOnly: speechOnly,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: maxActiveSignalRunDuration,
            lowConfidenceRMSCutoff: sessionLikelySilenceRMSCutoff,
            trueSilenceWindowRMSThreshold: sessionTrueSilenceWindowRMSThreshold
        )

        lastCaptureWasAbsoluteSilence = classification.isAbsoluteSilence
        lastCaptureHadActiveSignal = classification.hadActiveSignal
        lastCaptureWasLongTrueSilence = classification.isLongTrueSilence
        #if DEBUG
        let speechToAmbientRatio = classification.ambientFloorRMS > 0
            ? classification.speechRMS / classification.ambientFloorRMS
            : .infinity
        let noiseDominated = AudioSilenceGatePolicy.shouldRejectNoiseDominatedCapture(
            hadActiveSignal: classification.hadActiveSignal,
            speechRMS: classification.speechRMS,
            ambientFloorRMS: classification.ambientFloorRMS
        )
        print(
            "Audio silence classification: duration=\(String(format: "%.2f", captureDuration))s " +
            "activeSignal=\(lastCaptureHadActiveSignal) activeRun=\(String(format: "%.3f", maxActiveSignalRunDuration))s " +
            "silentWindowRatio=\(String(format: "%.3f", classification.silentWindowRatio)) " +
            "ambientFloor=\(String(format: "%.5f", classification.ambientFloorRMS)) " +
            "speechRMS=\(String(format: "%.5f", classification.speechRMS)) " +
            "speechToAmbientRatio=\(String(format: "%.3f", speechToAmbientRatio)) " +
            "noiseDominated=\(noiseDominated) rejectLikelySilence=\(classification.shouldRejectLikelySilence) " +
            "longTrueSilence=\(lastCaptureWasLongTrueSilence) " +
            "inputVolume=\(String(format: "%.2f", sessionInputVolumeScalar)) " +
            "thresholdScale=\(String(format: "%.2f", sessionThresholdScale))"
        )
        #endif

        let outputFrames: [Float]
        if lastCaptureWasLongTrueSilence {
            lastCaptureWasLikelySilence = false
            outputFrames = []
        } else if classification.shouldRejectLikelySilence {
            lastCaptureWasLikelySilence = true
            #if DEBUG
            print(
                "Audio processed: Rejected likely silence (duration: \(String(format: "%.2f", captureDuration))s, " +
                "hadActiveSignal: \(lastCaptureHadActiveSignal), speechRMS: \(classification.speechRMS))."
            )
            #endif
            outputFrames = []
        } else {
            lastCaptureWasLikelySilence = false
            #if DEBUG
            print("Audio processed: Preserving internal silence for transcription timing fidelity.")
            #endif
            outputFrames = AudioPostProcessing.normalizeForTranscription(
                snapshot,
                targetPeak: normalizationTargetPeak,
                maxGain: normalizationMaxGain
            )
        }

        return outputFrames
    }
}
