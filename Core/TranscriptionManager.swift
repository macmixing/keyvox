import SwiftUI
import Combine
import ApplicationServices

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
    private let dictionaryStore = DictionaryStore.shared
    private let postProcessor = TranscriptionPostProcessor()
    private var isLocked = false
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothStopSoundDelay: TimeInterval = 0.2
    private let defaultStopSoundDelay: TimeInterval = 0.0
    
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

        dictionaryStore.$entries
            .sink { [weak self] _ in
                guard let self else { return }
                self.postProcessor.updateDictionaryEntries(self.dictionaryStore.entries)
                let hintPrompt = self.dictionaryStore.whisperHintPrompt()
                self.whisperService.updateDictionaryHintPrompt(hintPrompt)
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
            if state == .recording {
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
        ModelDownloader.shared.refreshModelStatus()
        guard ModelDownloader.shared.isModelDownloaded else {
            OverlayManager.shared.hide()
            WarningManager.shared.show(.modelMissing)
            return
        }
        guard AXIsProcessTrusted() else {
            OverlayManager.shared.hide()
            WarningManager.shared.show(.accessibilityPermission)
            return
        }

        playSound(named: "Morse") // Start sound

        state = .recording
        WarningManager.shared.hide()
        OverlayManager.shared.show(recorder: audioRecorder)
        audioRecorder.startRecording()
    }
    
    private var stopRequestedAt: Date?
    
    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }
        
        let startTime = Date()
        stopRequestedAt = startTime
        #if DEBUG
        print("--- Speed Profile Start ---")
        #endif
        
        isLocked = false

        audioRecorder.stopRecording { [weak self] frames in
            guard let self = self else { return }
            
            // Root Cause Fix: Bluetooth HFP/SCO to A2DP switching delay.
            // NSSound cannot play into a Bluetooth Voice channel (HFP).
            // We must wait for the hardware to renegotiate back to high-quality A2DP.
            let isBluetooth = self.audioRecorder.currentDeviceKind == .bluetooth || self.audioRecorder.currentDeviceKind == .airPods
            let delay: TimeInterval = isBluetooth ? self.bluetoothStopSoundDelay : self.defaultStopSoundDelay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playSound(named: "Frog") // Stop sound
            }

            let stopDuration = Date().timeIntervalSince(startTime)
            #if DEBUG
            print("1. Audio stop & buffer retrieve: \(String(format: "%.3f", stopDuration))s")
            #endif
            
            guard !frames.isEmpty else {
                OverlayManager.shared.hide()
                if self.audioRecorder.lastCaptureWasAbsoluteSilence {
                    WarningManager.shared.show(.microphoneSilence)
                }
                self.state = .idle
                return
            }

            self.state = .transcribing
            
            // Transition overlay to transcription ripples only when we have frames to process.
            OverlayManager.shared.show(recorder: self.audioRecorder, isTranscribing: true)
            
            let transcribeStart = Date()
            self.whisperService.transcribe(audioFrames: frames) { result in
                let transcribeDuration = Date().timeIntervalSince(transcribeStart)
                #if DEBUG
                print("2. Whisper inference: \(String(format: "%.3f", transcribeDuration))s")
                #endif
                
                DispatchQueue.main.async {
                    let rawText = result ?? ""
                    let renderMode = PasteService.shared.preferredListRenderModeForFocusedElement()
                    let text = self.postProcessor.process(
                        rawText,
                        dictionaryEntries: self.dictionaryStore.entries,
                        renderMode: renderMode
                    )
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
