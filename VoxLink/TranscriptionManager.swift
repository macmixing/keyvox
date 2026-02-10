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
    
    private let keyboardMonitor = KeyboardMonitor()
    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
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
            startRecording()
        } else {
            stopRecordingAndTranscribe()
        }
    }
    
    private func startRecording() {
        guard case .idle = state else { return }
        state = .recording
        OverlayManager.shared.show()
        audioRecorder.startRecording()
    }
    
    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }
        
        OverlayManager.shared.hide()
        state = .transcribing
        audioRecorder.stopRecording { [weak self] audioURL in
            guard let self = self, let url = audioURL else {
                self?.state = .idle
                return
            }
            
            self.whisperService.transcribe(audioURL: url) { result in
                DispatchQueue.main.async {
                    let text = result ?? "[Transcription Empty]"
                    self.lastTranscription = text
                    PasteService.shared.pasteText(text)
                    self.state = .idle
                }
            }
        }
    }
}
