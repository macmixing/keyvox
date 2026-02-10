import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    
    @Published var isRecording = false
    
    var tempAudioURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Always recreate the engine for a fresh start
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        self.inputNode = inputNode
        
        // Use outputFormat(forBus: 0) which is more reliable for taps on macOS
        let tapFormat = inputNode.outputFormat(forBus: 0)
        
        do {
            if FileManager.default.fileExists(atPath: tempAudioURL.path) {
                try FileManager.default.removeItem(at: tempAudioURL)
            }
            
            // Record exactly what the tap provides
            audioFile = try AVAudioFile(forWriting: tempAudioURL, settings: tapFormat.settings)
        } catch {
            print("Could not create audio file: \(error)")
            return
        }
        
        // Remove existing tap just in case
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("Error writing to audio file: \(error)")
            }
        }
        
        engine.prepare()
        
        do {
            try engine.start()
            isRecording = true
            print("Recording started at rate: \(tapFormat.sampleRate) Hz...")
        } catch {
            print("Could not start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            isRecording = false
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        // Ensure we stop even if state is inconsistent
        defer {
            audioEngine?.stop()
            inputNode?.removeTap(onBus: 0)
            audioEngine = nil
            inputNode = nil
            audioFile = nil
            isRecording = false
            completion(tempAudioURL)
        }
        
        guard isRecording else { return }
        print("Recording stopped. File saved to: \(tempAudioURL)")
    }

}
