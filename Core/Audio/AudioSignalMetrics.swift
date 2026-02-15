import Foundation

enum AudioSignalMetrics {
    static func peak(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        var peak: Float = 0
        for sample in samples {
            let magnitude = abs(sample)
            if magnitude > peak {
                peak = magnitude
            }
        }
        return peak
    }

    static func rms(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        return sqrt(sumSquares / Float(samples.count))
    }

    static func trueSilenceWindowRatio(
        for samples: [Float],
        windowSize: Int,
        silenceThreshold: Float
    ) -> Float {
        guard !samples.isEmpty else { return 1.0 }
        guard windowSize > 0 else { return 0 }

        let totalWindows = samples.count / windowSize
        guard totalWindows > 0 else {
            return rms(of: samples) < silenceThreshold ? 1.0 : 0.0
        }

        var silentWindows = 0
        for windowIndex in 0..<totalWindows {
            let start = windowIndex * windowSize
            let end = start + windowSize
            let windowRMS = rms(of: Array(samples[start..<end]))
            if windowRMS < silenceThreshold {
                silentWindows += 1
            }
        }

        return Float(silentWindows) / Float(totalWindows)
    }
}
