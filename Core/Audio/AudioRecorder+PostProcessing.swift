import Foundation

extension AudioRecorder {
    func outputFramesForStoppedCapture() -> [Float] {
        // Preserve stop pipeline contract:
        // 1) snapshot raw audio
        // 2) run gap removal / silence rejection
        // 3) normalize loudness
        // 4) return processed frames
        let snapshot: [Float] = audioDataQueue.sync { audioData }
        let speechOnly = removeInternalGaps(from: snapshot)
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
        print(
            "Audio silence classification: duration=\(String(format: "%.2f", captureDuration))s " +
            "activeSignal=\(lastCaptureHadActiveSignal) activeRun=\(String(format: "%.3f", maxActiveSignalRunDuration))s " +
            "silentWindowRatio=\(String(format: "%.3f", classification.silentWindowRatio)) " +
            "ambientFloor=\(String(format: "%.5f", classification.ambientFloorRMS)) " +
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
            outputFrames = normalizeForTranscription(speechOnly)
        }

        return outputFrames
    }

    private func normalizeForTranscription(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var peak: Float = 0
        for sample in samples {
            let magnitude = abs(sample)
            if magnitude > peak {
                peak = magnitude
            }
        }

        guard peak > 0 else { return samples }

        let gain = normalizationTargetPeak / peak
        let clampedGain = min(gain, normalizationMaxGain)

        // If already near target, avoid an extra pass.
        guard abs(clampedGain - 1.0) > 0.01 else { return samples }

        return samples.map { sample in
            min(max(sample * clampedGain, -1.0), 1.0)
        }
    }

    private func removeInternalGaps(from samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let threshold = sessionGapRemovalRMSThreshold
        let windowSize = 1600 // 100ms at 16kHz
        let paddingWindows = 8 // Tuned: 800ms padding to prevent clipping
        let minSpeechWindows = 2
        let minAvgSpeechRMSMultiplier: Float = 1.15
        let shortUtterancePeakBypass: Float = 0.02

        let totalWindows = samples.count / windowSize
        // If recording is too short for windowing, just return it as is
        guard totalWindows > 0 else { return samples }

        var keepWindows = [Bool](repeating: false, count: totalWindows)
        var speechWindowCount = 0
        var speechRMSSum: Float = 0
        var peak: Float = 0

        // Phase 1: Identify speech windows
        for w in 0..<totalWindows {
            let start = w * windowSize
            let end = start + windowSize
            let window = samples[start..<end]

            var sumSquares: Float = 0
            for sample in window {
                sumSquares += sample * sample
                let magnitude = abs(sample)
                if magnitude > peak {
                    peak = magnitude
                }
            }
            let rms = sqrt(sumSquares / Float(windowSize))
            if rms > threshold {
                speechWindowCount += 1
                speechRMSSum += rms

                // Mark this window and padding around it
                let lowerBound = max(0, w - paddingWindows)
                let upperBound = min(totalWindows - 1, w + paddingWindows)
                for i in lowerBound...upperBound {
                    keepWindows[i] = true
                }
            }
        }

        // Reject mostly-silent clips so background noise doesn't get transcribed.
        if speechWindowCount == 0 {
            #if DEBUG
            print("Audio processed: No speech windows above threshold.")
            #endif
            return []
        }
        let avgSpeechRMS = speechRMSSum / Float(speechWindowCount)
        if speechWindowCount < minSpeechWindows && peak < shortUtterancePeakBypass {
            #if DEBUG
            print("Audio processed: Rejected low-energy short clip (speech windows: \(speechWindowCount), peak: \(peak)).")
            #endif
            return []
        }
        if avgSpeechRMS < threshold * minAvgSpeechRMSMultiplier {
            #if DEBUG
            print("Audio processed: Rejected low-energy clip (avgSpeechRMS: \(avgSpeechRMS), threshold: \(threshold)).")
            #endif
            return []
        }

        // Phase 2: Stitch kept windows together
        var processedSamples: [Float] = []
        for w in 0..<totalWindows {
            if keepWindows[w] {
                let start = w * windowSize
                let end = start + windowSize
                processedSamples.append(contentsOf: samples[start..<end])
            }
        }

        if processedSamples.isEmpty {
            #if DEBUG
            print("Audio processed: Resulted in total silence (Threshold: \(threshold))")
            #endif
            return []
        }

        let compression = Double(processedSamples.count) / Double(samples.count) * 100.0
        #if DEBUG
        print("Gap Removal: \(samples.count) -> \(processedSamples.count) frames (\(String(format: "%.1f", compression))% retained)")
        #endif

        return processedSamples
    }
}
