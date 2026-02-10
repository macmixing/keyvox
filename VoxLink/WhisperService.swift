import Foundation
import SwiftWhisper
import Combine
import AVFoundation

class WhisperService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    
    private var whisper: Whisper?
    
    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        guard let modelPath = getModelPath() else {
            print("Model not found. Please download a Whisper model first.")
            completion(nil)
            return
        }
        
        self.isTranscribing = true
        
        if whisper == nil {
            whisper = Whisper(fromFileURL: URL(fileURLWithPath: modelPath))
        }
        
        print("Starting transcription for: \(audioURL.path)")
        
        Task {
            do {
                // Step-by-step resampling to 16kHz
                let audioFrames = try loadAndResample(url: audioURL)
                
                print("Transcribing \(audioFrames.count) frames at 16kHz...")
                
                let segments = try await whisper?.transcribe(audioFrames: audioFrames)
                let text = segments?.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.transcriptionText = text ?? ""
                    completion(text)
                }
            } catch {
                print("Transcription error: \(error)")
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    completion(nil)
                }
            }
        }
    }
    
    private func loadAndResample(url: URL) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: url)
        let inputFormat = inputFile.processingFormat
        
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"])
        }
        
        let ratio = 16000.0 / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputFile.length) * ratio) + 1
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            throw NSError(domain: "WhisperService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inNumPackets)!
            do {
                try inputFile.read(into: inputBuffer)
                outStatus.pointee = .haveData
                return inputBuffer
            } catch {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if status == .error {
            throw error ?? NSError(domain: "WhisperService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])
        }
        
        guard let floatData = outputBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
    }
    
    private func getModelPath() -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voxLinkDir = appSupport.appendingPathComponent("VoxLink")
        
        let tinyModelURL = voxLinkDir.appendingPathComponent("ggml-tiny.en.bin")
        if FileManager.default.fileExists(atPath: tinyModelURL.path) {
            return tinyModelURL.path
        }
        
        let baseModelURL = voxLinkDir.appendingPathComponent("ggml-base.bin")
        if FileManager.default.fileExists(atPath: baseModelURL.path) {
            return baseModelURL.path
        }
        return nil
    }
}
