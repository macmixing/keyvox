import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var converter: AVAudioConverter?
    private var audioData: [Float] = []
    
    @Published var isRecording = false
    
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
