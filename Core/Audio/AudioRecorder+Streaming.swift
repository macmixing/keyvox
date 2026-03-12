import Foundation
import AVFoundation
import CoreMedia

extension AudioRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return }

        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              let sourceFormat = AVAudioFormat(streamDescription: asbdPointer),
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }

        sourceBuffer.frameLength = AVAudioFrameCount(frameCount)

        let copyStatus = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: sourceBuffer.mutableAudioBufferList
        )

        guard copyStatus == noErr else { return }

        // Setup converter for real-time resampling.
        if converter == nil || shouldRebuildConverter(for: sourceFormat) {
            converter = AVAudioConverter(from: sourceFormat, to: outputFormat)
        }

        guard let converter = converter else { return }

        let outputCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * outputFormat.sampleRate / sourceFormat.sampleRate) + 1
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else { return }

        var conversionError: NSError?
        var providedInput = false
        let conversionStatus = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if providedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            providedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        guard conversionStatus != .error, convertedBuffer.frameLength > 0,
              let floatData = convertedBuffer.floatChannelData else {
            return
        }

        let frames = Array(UnsafeBufferPointer(start: floatData[0], count: Int(convertedBuffer.frameLength)))
        audioDataQueue.sync {
            audioData.append(contentsOf: frames)
        }

        // Calculate RMS for UI visualization.
        var sum: Float = 0
        var peak: Float = 0
        for frame in frames {
            sum += frame * frame
            let magnitude = abs(frame)
            if magnitude > peak {
                peak = magnitude
            }
        }

        let rms = sqrt(sum / Float(frames.count))
        let frameDuration = TimeInterval(Double(convertedBuffer.frameLength) / outputFormat.sampleRate)

        // Visual meter scaling only. This does not modify captured audio samples.
        // Keep boosted UI response so waveform movement remains readable.
        let level = min(max(sqrt(rms) * 2.5, 0.0), 1.0)

        let now = Date()
        if peak > deadSignalPeakThreshold {
            lastNonDeadSignalTime = now
            lastCaptureHadNonDeadSignal = true
        }
        if rms > sessionActiveSignalRMSThreshold {
            currentActiveSignalRunDuration += frameDuration
            if currentActiveSignalRunDuration > maxActiveSignalRunDuration {
                maxActiveSignalRunDuration = currentActiveSignalRunDuration
            }
        } else {
            currentActiveSignalRunDuration = 0
        }

        let visualActiveThreshold = sessionActiveSignalRMSThreshold * visualActiveSignalThresholdMultiplier
        if rms > visualActiveThreshold {
            lastVisualActiveSignalTime = now
        }

        let isDead = now.timeIntervalSince(lastNonDeadSignalTime) > deadStateHoldDuration
        let isActive = now.timeIntervalSince(lastVisualActiveSignalTime) <= visualActiveStateHoldDuration
        let signalState: LiveInputSignalState = isDead ? .dead : (isActive ? .active : .quiet)

        DispatchQueue.main.async {
            self.audioLevel = level
            let isQuiet = signalState != .active
            if self.isVisualQuiet != isQuiet {
                self.isVisualQuiet = isQuiet
            }
            if self.liveInputSignalState != signalState {
                self.liveInputSignalState = signalState
            }
        }
    }

    private func shouldRebuildConverter(for inputFormat: AVAudioFormat) -> Bool {
        guard let existingConverter = converter else { return true }

        let existingInput = existingConverter.inputFormat
        if existingInput.sampleRate != inputFormat.sampleRate { return true }
        if existingInput.channelCount != inputFormat.channelCount { return true }
        if existingInput.commonFormat != inputFormat.commonFormat { return true }
        if existingInput.isInterleaved != inputFormat.isInterleaved { return true }

        return false
    }
}
