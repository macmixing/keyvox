import Foundation
import AVFoundation

extension AudioRecorder {
    func processCapturedBuffer(_ sourceBuffer: AVAudioPCMBuffer) {
        let frameCount = Int(sourceBuffer.frameLength)
        let channelCount = Int(sourceBuffer.format.channelCount)
        guard frameCount > 0,
              channelCount > 0,
              sourceBuffer.format.commonFormat == .pcmFormatFloat32,
              !sourceBuffer.format.isInterleaved,
              let sourceChannels = sourceBuffer.floatChannelData,
              let monoFormat = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: sourceBuffer.format.sampleRate,
                  channels: 1,
                  interleaved: false
              ),
              let monoBuffer = AVAudioPCMBuffer(
                  pcmFormat: monoFormat,
                  frameCapacity: sourceBuffer.frameLength
              ),
              let monoChannel = monoBuffer.floatChannelData?[0] else {
            return
        }

        monoBuffer.frameLength = sourceBuffer.frameLength
        for frameIndex in 0..<frameCount {
            var mixedSample: Float = 0
            for channelIndex in 0..<channelCount {
                let sample = sourceChannels[channelIndex][frameIndex]
                if sample.isFinite {
                    mixedSample += sample
                }
            }
            monoChannel[frameIndex] = min(max(mixedSample, -1), 1)
        }

        if converter == nil || shouldRebuildConverter(for: monoFormat) {
            converter = AVAudioConverter(from: monoFormat, to: outputFormat)
        }

        guard let converter else { return }

        let outputCapacity = AVAudioFrameCount(Double(monoBuffer.frameLength) * outputFormat.sampleRate / monoFormat.sampleRate) + 1
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
            return monoBuffer
        }

        guard conversionStatus != .error, convertedBuffer.frameLength > 0,
              let floatData = convertedBuffer.floatChannelData else {
            return
        }

        let frames = Array(UnsafeBufferPointer(start: floatData[0], count: Int(convertedBuffer.frameLength)))
        audioDataQueue.sync {
            audioData.append(contentsOf: frames)
        }

        let sampleInterval = 1 / Float(outputFormat.sampleRate)
        let highPassTimeConstant = 1 / (2 * Float.pi * visualMeterHighPassCutoffFrequency)
        let highPassCoefficient = highPassTimeConstant / (highPassTimeConstant + sampleInterval)

        // Calculate raw capture RMS and a high-passed RMS for UI visualization.
        var sum: Float = 0
        var visualSum: Float = 0
        var peak: Float = 0
        var previousVisualInput = visualMeterPreviousInput
        var previousVisualOutput = visualMeterPreviousOutput
        for frame in frames {
            sum += frame * frame

            let visualFrame = highPassCoefficient * (previousVisualOutput + frame - previousVisualInput)
            visualSum += visualFrame * visualFrame
            previousVisualInput = frame
            previousVisualOutput = visualFrame

            let magnitude = abs(frame)
            if magnitude > peak {
                peak = magnitude
            }
        }
        visualMeterPreviousInput = previousVisualInput
        visualMeterPreviousOutput = previousVisualOutput

        let rms = sqrt(sum / Float(frames.count))
        let visualMeterRMS = sqrt(visualSum / Float(frames.count))
        let frameDuration = TimeInterval(Double(convertedBuffer.frameLength) / outputFormat.sampleRate)

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
        // Visual meter scaling only. This does not modify captured audio samples.
        // Remove low-level background noise before boosting the remaining signal.
        let visualRMS = max(visualMeterRMS - visualActiveThreshold, 0)
        let level = min(sqrt(visualRMS) * 5.5, 1.0)

        if visualMeterRMS > visualActiveThreshold {
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
