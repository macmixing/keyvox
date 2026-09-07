import Foundation

/// Windowed-sinc conversion with a low-pass cutoff when reducing sample rate.
/// The equal-rate path preserves samples exactly. No platform DSP dependency.
enum PCMResampler {
    enum Failure: Error { case invalidSampleRate, nonFiniteSample, outputTooLarge }

    // Bounds the work and expansion of this in-memory speech-file converter.
    // These are format support limits, not recording-duration limits.
    static let supportedSampleRates = 8_000...384_000

    static func resample(_ samples: [Float], from inputRate: Int, to outputRate: Int) throws -> [Float] {
        guard supportedSampleRates.contains(inputRate), supportedSampleRates.contains(outputRate) else {
            throw Failure.invalidSampleRate
        }
        guard samples.allSatisfy(\.isFinite) else { throw Failure.nonFiniteSample }
        guard inputRate != outputRate, !samples.isEmpty else { return samples }
        let ratio = Double(outputRate) / Double(inputRate)
        let length = (Double(samples.count) * ratio).rounded(.up)
        guard length < Double(Int.max) else { throw Failure.outputTooLarge }
        let cutoff = min(1, ratio)
        let radius = 32.0 / cutoff
        var output = [Float]()
        output.reserveCapacity(Int(length))
        for index in 0..<Int(length) {
            let position = Double(index) / ratio
            let lower = Int(max(0, ceil(position - radius)))
            let upper = Int(min(Double(samples.count - 1), floor(position + radius)))
            var sum = 0.0
            var weights = 0.0
            for source in lower...upper {
                let distance = Double(source) - position
                let phase = Double.pi * distance * cutoff
                let sinc = abs(phase) < 1e-12 ? 1 : sin(phase) / phase
                let window = 0.5 * (1 + cos(Double.pi * distance / radius))
                let weight = cutoff * sinc * window
                sum += Double(samples[source]) * weight
                weights += weight
            }
            let value = Float(sum / weights)
            guard value.isFinite else { throw Failure.nonFiniteSample }
            output.append(value)
        }
        return output
    }
}
