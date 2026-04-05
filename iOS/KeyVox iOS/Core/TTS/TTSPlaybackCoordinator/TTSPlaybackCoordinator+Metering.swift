import AVFoundation
import Foundation

extension TTSPlaybackCoordinator {
    func scheduleMeterUpdates(for samples: [Float], startDelay: TimeInterval) {
        guard !samples.isEmpty else { return }

        let sampleRate = playbackFormat.sampleRate
        let now = DispatchTime.now()
        var windowStart = 0

        while windowStart < samples.count {
            let windowEnd = min(windowStart + MeterPolicy.windowSampleCount, samples.count)
            let windowSamples = Array(samples[windowStart..<windowEnd])
            let meterLevel = max(playbackMeterLevel(for: windowSamples), MeterPolicy.minimumUpdateLevel)
            let windowOffset = TimeInterval(windowStart) / sampleRate
            let workItem = DispatchWorkItem { [weak self] in
                self?.onPlaybackMeterLevel?(meterLevel)
            }
            scheduledMeterUpdates.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: now + startDelay + windowOffset, execute: workItem)

            if windowEnd == samples.count {
                break
            }

            windowStart += MeterPolicy.windowStepCount
        }
    }

    func cancelScheduledMeterUpdates() {
        scheduledMeterUpdates.forEach { $0.cancel() }
        scheduledMeterUpdates.removeAll(keepingCapacity: false)
    }

    func copySamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?.pointee else { return [] }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channel, count: frameLength))
    }

    func playbackMeterLevel(for samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        var peak: Float = 0
        let meanSquare = samples.reduce(Float.zero) { partialResult, sample in
            let magnitude = abs(sample)
            peak = max(peak, magnitude)
            return partialResult + (sample * sample)
        } / Float(samples.count)

        let rms = sqrt(meanSquare)
        let rmsDriven = rms * 8.8
        let peakDriven = peak * 2.1
        return min(max(max(rmsDriven, peakDriven), 0), 1)
    }
}
