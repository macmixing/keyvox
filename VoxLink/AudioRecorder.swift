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
        
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        // Use the HARDWARE format to ensure zero resampling issues during capture
        let hardwareFormat = inputNode?.inputFormat(forBus: 0)
        
        do {
            if FileManager.default.fileExists(atPath: tempAudioURL.path) {
                try FileManager.default.removeItem(at: tempAudioURL)
            }
            
            // Record exactly what the hardware provides
            audioFile = try AVAudioFile(forWriting: tempAudioURL, settings: hardwareFormat!.settings)
        } catch {
            print("Could not create audio file: \(error)")
            return
        }
        
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("Error writing to audio file: \(error)")
            }
        }
        
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
            isRecording = true
            print("Recording started at hardware rate: \(hardwareFormat?.sampleRate ?? 0) Hz...")
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else { 
            completion(nil)
            return 
        }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        isRecording = false
        
        print("Recording stopped. File saved to: \(tempAudioURL)")
        completion(tempAudioURL)
    }
}
