import SwiftUI
import Combine

class TranscriptionManager: ObservableObject {
    @Published var state: AppState = .idle
    @Published var lastTranscription: String = ""
    
    enum AppState: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }
    
    let keyboardMonitor = KeyboardMonitor.shared
    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()
    private var targetApp: NSRunningApplication?
    private var isLocked = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        whisperService.warmup()
    }
    
    private func setupBindings() {
        keyboardMonitor.$isTriggerKeyPressed
            .sink { [weak self] isPressed in
                self?.handleTriggerKey(isPressed: isPressed)
            }
            .store(in: &cancellables)
    }
    
    private func handleTriggerKey(isPressed: Bool) {
        if isPressed {
            if state == .idle {
                startRecording()
            } else if state == .recording && isLocked {
                // If we are locked and press the key again, stop recording
                isLocked = false
                stopRecordingAndTranscribe()
            }
        } else {
            // Key released
            if state == .recording {
                if keyboardMonitor.isShiftPressed {
                    isLocked = true
                    print("Hands-free mode LOCKED")
                } else if !isLocked {
                    stopRecordingAndTranscribe()
                }
            }
        }
    }
    
    private func startRecording() {
        guard case .idle = state else { return }
        
        playSound(named: "Morse") // Start sound
        state = .recording
        OverlayManager.shared.show(recorder: audioRecorder)
        audioRecorder.startRecording()
    }
    
    private var stopRequestedAt: Date?
    
    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }
        
        let startTime = Date()
        stopRequestedAt = startTime
        print("--- Speed Profile Start ---")
        
        playSound(named: "Frog") // Stop sound
        state = .transcribing
        isLocked = false
        
        // Keep overlay visible but show transcription ripples
        OverlayManager.shared.show(recorder: audioRecorder, isTranscribing: true)
        
        audioRecorder.stopRecording { [weak self] frames in
            let stopDuration = Date().timeIntervalSince(startTime)
            print("1. Audio stop & buffer retrieve: \(String(format: "%.3f", stopDuration))s")
            
            guard let self = self, !frames.isEmpty else {
                OverlayManager.shared.hide()
                self?.state = .idle
                return
            }
            
            let transcribeStart = Date()
            self.whisperService.transcribe(audioFrames: frames) { result in
                let transcribeDuration = Date().timeIntervalSince(transcribeStart)
                print("2. Whisper inference: \(String(format: "%.3f", transcribeDuration))s")
                
                DispatchQueue.main.async {
                    let text = result ?? ""
                    self.lastTranscription = text
                    
                    let pasteStart = Date()
                    if !text.isEmpty {
                        PasteService.shared.pasteText(text)
                    }
                    let pasteDuration = Date().timeIntervalSince(pasteStart)
                    print("3. Injection trigger: \(String(format: "%.3f", pasteDuration))s")
                    
                    let totalTime = Date().timeIntervalSince(startTime)
                    print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
                    print("--- Speed Profile End ---")
                    
                    // Hide overlay only after transcription completes
                    OverlayManager.shared.hide()
                    self.state = .idle
                }
            }
        }
    }
    
    private func playSound(named name: String) {
        if let sound = NSSound(named: name) {
            sound.volume = 0.1 // 10% volume
            sound.play()
        }
    }
}
