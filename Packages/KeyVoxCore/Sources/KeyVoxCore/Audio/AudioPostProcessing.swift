import Foundation

public enum AudioPostProcessing {
    public static func normalizeForTranscription(
        _ samples: [Float],
        targetPeak: Float = 0.9,
        maxGain: Float = 3.0
    ) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var peak: Float = 0
        for sample in samples {
            let magnitude = abs(sample)
            if magnitude > peak {
                peak = magnitude
            }
        }

        guard peak > 0 else { return samples }

        let gain = targetPeak / peak
        let clampedGain = min(gain, maxGain)

        guard abs(clampedGain - 1.0) > 0.01 else { return samples }

        return samples.map { sample in
            min(max(sample * clampedGain, -1.0), 1.0)
        }
    }

    public static func removeInternalGaps(
        from samples: [Float],
        gapRemovalRMSThreshold threshold: Float
    ) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let windowSize = 1600
        let paddingWindows = 8
        let minSpeechWindows = 2
        let minAvgSpeechRMSMultiplier: Float = 1.15
        let shortUtterancePeakBypass: Float = 0.02

        let totalWindows = samples.count / windowSize
        guard totalWindows > 0 else { return samples }

        var keepWindows = [Bool](repeating: false, count: totalWindows)
        var speechWindowCount = 0
        var speechRMSSum: Float = 0
        var peak: Float = 0

        for windowIndex in 0..<totalWindows {
            let start = windowIndex * windowSize
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

                let lowerBound = max(0, windowIndex - paddingWindows)
                let upperBound = min(totalWindows - 1, windowIndex + paddingWindows)
                for index in lowerBound...upperBound {
                    keepWindows[index] = true
                }
            }
        }

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

        var processedSamples: [Float] = []
        for windowIndex in 0..<totalWindows {
            if keepWindows[windowIndex] {
                let start = windowIndex * windowSize
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
