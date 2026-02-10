import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var converter: AVAudioConverter?
    private var audioData: [Float] = []
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
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
        audioData.removeAll()
        
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
                self.audioData.append(contentsOf: frames)
                
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
                
                DispatchQueue.main.async {
                    self.audioLevel = level
                }
            }
        }
        
        engine.prepare()
        
        do {
            try engine.start()
            isRecording = true
            print("Recording started (Direct to Memory @ 16kHz)...")
        } catch {
            print("Could not start audio engine: \(error)")
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
            completion(audioData)
        }
        
        guard isRecording else { return }
        print("Recording stopped. Captured \(audioData.count) frames.")
    }
}
