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
    private var isLocked = false
    private var cancellables = Set<AnyCancellable>()
    private let startCueLeadIn: TimeInterval = 0.18
    private var pendingStartWorkItem: DispatchWorkItem?
    
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
            
        keyboardMonitor.$escapePressedSignal
            .dropFirst()
            .sink { [weak self] _ in
                self?.abortRecording()
            }
            .store(in: &cancellables)
    }
    
    private func abortRecording() {
        guard state == .recording || state == .transcribing else { return }
        
        #if DEBUG
        print("!! ESCAPE pressed: Aborting session !!")
        #endif
        
        playSound(named: "Bottle") // Cancel sound
        audioRecorder.stopRecording { _ in }
        whisperService.cancelTranscription()
        isLocked = false
        OverlayManager.shared.hide()
        state = .idle
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
            if state == .idle {
                // Fast tap path: cancel delayed recording start before it enters `.recording`.
                pendingStartWorkItem?.cancel()
                pendingStartWorkItem = nil
            } else if state == .recording {
                if keyboardMonitor.isShiftPressed {
                    isLocked = true
                    #if DEBUG
                    print("Hands-free mode LOCKED")
                    #endif
                } else if !isLocked {
                    stopRecordingAndTranscribe()
                }
            }
        }
    }
    
    private func startRecording() {
        guard case .idle = state else { return }

        playSound(named: "Morse") // Start sound

        pendingStartWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingStartWorkItem = nil
            guard self.state == .idle, self.keyboardMonitor.isTriggerKeyPressed else { return }

            self.state = .recording
            OverlayManager.shared.show(recorder: self.audioRecorder)
            self.audioRecorder.startRecording()
        }
        pendingStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + startCueLeadIn, execute: workItem)
    }
    
    private var stopRequestedAt: Date?
    
    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }
        
        let startTime = Date()
        stopRequestedAt = startTime
        #if DEBUG
        print("--- Speed Profile Start ---")
        #endif
        
        state = .transcribing
        isLocked = false
        
        // Keep overlay visible but show transcription ripples
        OverlayManager.shared.show(recorder: audioRecorder, isTranscribing: true)
        
        audioRecorder.stopRecording { [weak self] frames in
            self?.playSound(named: "Frog") // Stop sound

            let stopDuration = Date().timeIntervalSince(startTime)
            #if DEBUG
            print("1. Audio stop & buffer retrieve: \(String(format: "%.3f", stopDuration))s")
            #endif
            
            guard let self = self, !frames.isEmpty else {
                OverlayManager.shared.hide()
                self?.state = .idle
                return
            }
            
            let transcribeStart = Date()
            self.whisperService.transcribe(audioFrames: frames) { result in
                let transcribeDuration = Date().timeIntervalSince(transcribeStart)
                #if DEBUG
                print("2. Whisper inference: \(String(format: "%.3f", transcribeDuration))s")
                #endif
                
                DispatchQueue.main.async {
                    let text = result ?? ""
                    self.lastTranscription = text
                    
                    let pasteStart = Date()
                    if !text.isEmpty {
                        PasteService.shared.pasteText(text)
                    }
                    let pasteDuration = Date().timeIntervalSince(pasteStart)
                    #if DEBUG
                    print("3. Injection trigger: \(String(format: "%.3f", pasteDuration))s")
                    #endif
                    
                    let totalTime = Date().timeIntervalSince(startTime)
                    #if DEBUG
                    print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
                    print("--- Speed Profile End ---")
                    #endif
                    
                    // Hide overlay only after transcription completes
                    OverlayManager.shared.hide()
                    self.state = .idle
                }
            }
        }
    }
    
    private func playSound(named name: String) {
        guard keyboardMonitor.isSoundEnabled else { return }
        if let sound = NSSound(named: name) {
            sound.volume = 0.1 // 10% volume
            sound.play()
        }
    }
}
