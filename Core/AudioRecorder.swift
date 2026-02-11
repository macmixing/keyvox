import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var converter: AVAudioConverter?
    private var audioData: [Float] = []
    private let audioDataQueue = DispatchQueue(label: "AudioRecorder.audioDataQueue")
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var isVisualQuiet = true
    private var lastSpeechTime: Date = Date.distantPast
    
    func startRecording() {
        guard !isRecording else { return }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        self.inputNode = inputNode
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        // Setup converter for real-time resampling
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        audioDataQueue.sync {
            audioData.removeAll()
        }
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self, let converter = self.converter else { return }
            
            let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate) + 1
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else { return }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            if let floatData = outputBuffer.floatChannelData {
                let frames = Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
                self.audioDataQueue.sync {
                    self.audioData.append(contentsOf: frames)
                }
                
                // Calculate RMS for UI visualization
                var sum: Float = 0
                for frame in frames {
                    sum += frame * frame
                }
                let rms = sqrt(sum / Float(frames.count))
                
                // Non-linear boost (Square root) to make quiet sounds visible
                // RMS of 0.01 (quiet) -> 0.1 * 5.0 = 0.5 (Half bar)
                // RMS of 0.04 (normal) -> 0.2 * 5.0 = 1.0 (Full bar)
                let level = min(max(sqrt(rms) * 5.0, 0.0), 1.0)
                
                if level > 0.15 {
                    self.lastSpeechTime = Date()
                }
                
                let isNowQuiet = Date().timeIntervalSince(self.lastSpeechTime) > 0.8
                
                DispatchQueue.main.async {
                    self.audioLevel = level
                    if self.isVisualQuiet != isNowQuiet {
                        self.isVisualQuiet = isNowQuiet
                    }
                }
            }
        }
        
        engine.prepare()
        
        do {
            try engine.start()
            isRecording = true
            #if DEBUG
            print("Recording started (Direct to Memory @ 16kHz)...")
            #endif
        } catch {
            #if DEBUG
            print("Could not start audio engine: \(error)")
            #endif
            inputNode.removeTap(onBus: 0)
            isRecording = false
        }
    }
    
    func stopRecording(completion: @escaping ([Float]) -> Void) {
        defer {
            audioEngine?.stop()
            inputNode?.removeTap(onBus: 0)
            audioEngine = nil
            inputNode = nil
            converter = nil
            isRecording = false
            
            let snapshot: [Float] = audioDataQueue.sync { audioData }
            let processed = removeInternalGaps(from: snapshot)
            completion(processed)
        }
        
        guard isRecording else { return }
        #if DEBUG
        print("Recording stopped. Captured \(audioData.count) frames.")
        #endif
    }
    
    private func removeInternalGaps(from samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        let threshold: Float = 0.002 // Tuned: Sensitive enough for quiet speech
        let windowSize = 1600 // 100ms at 16kHz
        let paddingWindows = 8 // Tuned: 800ms padding to prevent clipping
        
        let totalWindows = samples.count / windowSize
        // If recording is too short for windowing, just return it as is
        guard totalWindows > 0 else { return samples }
        
        var keepWindows = [Bool](repeating: false, count: totalWindows)
        
        // Phase 1: Identify speech windows
        for w in 0..<totalWindows {
            let start = w * windowSize
            let end = start + windowSize
            let window = samples[start..<end]
            
            let rms = sqrt(window.reduce(0) { $0 + $1 * $1 } / Float(windowSize))
            if rms > threshold {
                // Mark this window and padding around it
                let lowerBound = max(0, w - paddingWindows)
                let upperBound = min(totalWindows - 1, w + paddingWindows)
                for i in lowerBound...upperBound {
                    keepWindows[i] = true
                }
            }
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
