import Foundation
import AVFoundation
import Combine
import CoreMedia

class AudioRecorder: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private var captureInput: AVCaptureDeviceInput?
    private var captureOutput: AVCaptureAudioDataOutput?
    private var converter: AVAudioConverter?

    private var audioData: [Float] = []
    private let audioDataQueue = DispatchQueue(label: "AudioRecorder.audioDataQueue")
    private let captureQueue = DispatchQueue(label: "AudioRecorder.captureQueue")
    // Recorder contract is still mono Float32 @ 16kHz for downstream transcription.
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    private let normalizationTargetPeak: Float = 0.9
    private let normalizationMaxGain: Float = 3.0

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var isVisualQuiet = true
    private var lastSpeechTime: Date = Date.distantPast

    func startRecording() {
        guard !isRecording else { return }

        let session = AVCaptureSession()
        session.beginConfiguration()

        // App-scoped input selection: selected mic -> built-in -> first available.
        guard let device = AudioDeviceManager.shared.resolvedCaptureDevice()
            ?? AudioDeviceManager.shared.builtInCaptureDevice()
            ?? AVCaptureDevice.default(for: .audio)
            ?? Self.captureAudioDevices().first else {
            session.commitConfiguration()
            return
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            return
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        session.commitConfiguration()

        captureSession = session
        captureInput = input
        captureOutput = output

        // Converter is rebuilt lazily when first buffer arrives (or source format changes).
        converter = nil

        audioDataQueue.sync {
            audioData.removeAll()
        }

        lastSpeechTime = Date.distantPast

        session.startRunning()
        isRecording = true
    }

    func stopRecording(completion: @escaping ([Float]) -> Void) {
        defer {
            captureOutput?.setSampleBufferDelegate(nil, queue: nil)
            captureSession?.stopRunning()

            captureSession = nil
            captureInput = nil
            captureOutput = nil
            converter = nil
            isRecording = false

            // Preserve stop pipeline contract:
            // 1) snapshot raw audio
            // 2) run gap removal / silence rejection
            // 3) normalize loudness
            // 4) return processed frames
            let snapshot: [Float] = audioDataQueue.sync { audioData }
            let speechOnly = removeInternalGaps(from: snapshot)
            let normalized = normalizeForTranscription(speechOnly)
            completion(normalized)
        }

        guard isRecording else { return }
    }

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
        for frame in frames {
            sum += frame * frame
        }

        let rms = sqrt(sum / Float(frames.count))

        // Visual meter scaling only. This does not modify captured audio samples.
        // Keep boosted UI response so waveform movement remains readable.
        let level = min(max(sqrt(rms) * 5.0, 0.0), 1.0)

        if level > 0.15 {
            lastSpeechTime = Date()
        }

        let isNowQuiet = Date().timeIntervalSince(lastSpeechTime) > 0.8

        DispatchQueue.main.async {
            self.audioLevel = level
            if self.isVisualQuiet != isNowQuiet {
                self.isVisualQuiet = isNowQuiet
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

        let threshold: Float = 0.002 // Tuned: Sensitive enough for quiet speech
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

    private static func captureAudioDevices() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices
    }
}
