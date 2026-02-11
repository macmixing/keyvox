import Foundation
import SwiftWhisper
import Combine
import AVFoundation

class WhisperService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    
    private var whisper: Whisper?
    
    /// Pre-loads the model into memory to eliminate cold-start latency.
    func warmup() {
        guard whisper == nil else { return }
        guard let modelPath = getModelPath() else { return }
        
        #if DEBUG
        print("Warming up Whisper model with optimized settings...")
        #endif
        
        let params = WhisperParams.default
        params.language = .english
        params.n_threads = 4 // Optimal for M-series P-cores (prevent oversubscription)
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_non_speech_tokens = true
        // CoreML is automatic if the model files are present
        
        whisper = Whisper(fromFileURL: URL(fileURLWithPath: modelPath), withParams: params)
    }
    
    func transcribe(audioFrames: [Float], completion: @escaping (String?) -> Void) {
        guard !audioFrames.isEmpty else {
            #if DEBUG
            print("Skipping transcription: audio buffer is empty or silent.")
            #endif
            completion("")
            return
        }
        
        self.isTranscribing = true
        
        // Ensure model is loaded (if warmup wasn't called/finished)
        if whisper == nil {
            warmup()
        }
        
        #if DEBUG
        print("Transcribing \(audioFrames.count) raw frames...")
        #endif
        
        Task {
            do {
                let segments = try await whisper?.transcribe(audioFrames: audioFrames)
                let text = segments?.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // Collapse multiple spaces into a single space
                let cleanedText = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.transcriptionText = cleanedText
                    completion(cleanedText)
                }
            } catch {
                #if DEBUG
                print("Transcription error: \(error)")
                #endif
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    completion(nil)
                }
            }
        }
    }
    
    // Legacy support for file-based transcription (can be removed later)
    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        Task {
            do {
                let audioFrames = try loadAndResample(url: audioURL)
                transcribe(audioFrames: audioFrames, completion: completion)
            } catch {
                completion(nil)
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
        let KeyVoxDir = appSupport.appendingPathComponent("KeyVox")
        
        // Check for Base model first (Upgrade)
        let baseModelURL = KeyVoxDir.appendingPathComponent("ggml-base.en.bin")
        if FileManager.default.fileExists(atPath: baseModelURL.path) {
            return baseModelURL.path
        }
        
        return nil
    }
}
