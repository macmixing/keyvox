import AVFoundation
import Foundation

struct iOSCaptureMeterUpdate: Equatable {
    let level: Float
    let signalState: LiveInputSignalState
}

struct iOSAudioStreamSnapshot {
    let samples: [Float]
    let maxActiveSignalRunDuration: TimeInterval
    let hadNonDeadSignal: Bool
}

struct iOSLiveCaptureMetrics {
    let duration: TimeInterval
    let hadMeaningfulSpeech: Bool
    let timeSinceLastMeaningfulSpeech: TimeInterval?
}

final class iOSAudioCaptureAccumulator {
    private let queue = DispatchQueue(label: "iOSAudioRecorder.captureAccumulator")
    private var converter: AVAudioConverter?
    private var audioData: [Float] = []
    private var lastNonDeadSignalTime: Date = .distantPast
    private var lastVisualActiveSignalTime: Date = .distantPast
    private var lastMeaningfulSpeechTime: Date = .distantPast
    private var currentActiveSignalRunDuration: TimeInterval = 0
    private var maxActiveSignalRunDuration: TimeInterval = 0
    private var hadNonDeadSignal = false

    func reset() {
        queue.sync {
            converter = nil
            audioData.removeAll(keepingCapacity: true)
            lastNonDeadSignalTime = .distantPast
            lastVisualActiveSignalTime = .distantPast
            lastMeaningfulSpeechTime = .distantPast
            currentActiveSignalRunDuration = 0
            maxActiveSignalRunDuration = 0
            hadNonDeadSignal = false
        }
    }

    func snapshot() -> iOSAudioStreamSnapshot {
        queue.sync {
            iOSAudioStreamSnapshot(
                samples: audioData,
                maxActiveSignalRunDuration: maxActiveSignalRunDuration,
                hadNonDeadSignal: hadNonDeadSignal
            )
        }
    }

    func liveMetrics(sampleRate: Double) -> iOSLiveCaptureMetrics {
        queue.sync {
            let duration = sampleRate > 0 ? TimeInterval(Double(audioData.count) / sampleRate) : 0
            let hadMeaningfulSpeech = lastMeaningfulSpeechTime != .distantPast
            let timeSinceLastMeaningfulSpeech = hadMeaningfulSpeech
                ? Date().timeIntervalSince(lastMeaningfulSpeechTime)
                : nil
            return iOSLiveCaptureMetrics(
                duration: duration,
                hadMeaningfulSpeech: hadMeaningfulSpeech,
                timeSinceLastMeaningfulSpeech: timeSinceLastMeaningfulSpeech
            )
        }
    }

    func process(
        inputBuffer: AVAudioPCMBuffer,
        outputFormat: AVAudioFormat,
        deadSignalPeakThreshold: Float,
        activeSignalRMSThreshold: Float,
        visualActiveSignalThresholdMultiplier: Float,
        deadStateHoldDuration: TimeInterval,
        visualActiveStateHoldDuration: TimeInterval
    ) -> iOSCaptureMeterUpdate? {
        queue.sync {
            let sourceFormat = inputBuffer.format
            if converter == nil || shouldRebuildConverter(for: sourceFormat) {
                converter = AVAudioConverter(from: sourceFormat, to: outputFormat)
            }

            guard let converter else { return nil }

            let outputCapacity = AVAudioFrameCount(
                ceil(Double(inputBuffer.frameLength) * outputFormat.sampleRate / sourceFormat.sampleRate)
            ) + 1
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
                return nil
            }

            var conversionError: NSError?
            var providedInput = false
            let conversionStatus = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                if providedInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                providedInput = true
                outStatus.pointee = .haveData
                return inputBuffer
            }

            guard conversionStatus != .error,
                  convertedBuffer.frameLength > 0,
                  let floatData = convertedBuffer.floatChannelData else {
                return nil
            }

            let frameCount = Int(convertedBuffer.frameLength)
            let frames = Array(UnsafeBufferPointer(start: floatData[0], count: frameCount))
            audioData.append(contentsOf: frames)

            var sumSquares: Float = 0
            var peak: Float = 0
            for frame in frames {
                sumSquares += frame * frame
                let magnitude = abs(frame)
                if magnitude > peak {
                    peak = magnitude
                }
            }

            let rms = sqrt(sumSquares / Float(frameCount))
            let frameDuration = TimeInterval(Double(convertedBuffer.frameLength) / outputFormat.sampleRate)
            let level = min(max(sqrt(rms) * 5.0, 0), 1)

            let now = Date()
            if peak > deadSignalPeakThreshold {
                lastNonDeadSignalTime = now
                hadNonDeadSignal = true
            }
            if rms > activeSignalRMSThreshold {
                lastMeaningfulSpeechTime = now
                currentActiveSignalRunDuration += frameDuration
                if currentActiveSignalRunDuration > maxActiveSignalRunDuration {
                    maxActiveSignalRunDuration = currentActiveSignalRunDuration
                }
            } else {
                currentActiveSignalRunDuration = 0
            }

            let visualActiveThreshold = activeSignalRMSThreshold * visualActiveSignalThresholdMultiplier
            if rms > visualActiveThreshold {
                lastVisualActiveSignalTime = now
            }

            let isDead = now.timeIntervalSince(lastNonDeadSignalTime) > deadStateHoldDuration
            let isActive = now.timeIntervalSince(lastVisualActiveSignalTime) <= visualActiveStateHoldDuration
            let signalState: LiveInputSignalState = isDead ? .dead : (isActive ? .active : .quiet)
            return iOSCaptureMeterUpdate(level: level, signalState: signalState)
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
