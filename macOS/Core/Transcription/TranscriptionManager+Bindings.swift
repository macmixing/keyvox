import Combine
import Foundation
import KeyVoxCore

extension TranscriptionManager {
    func setupBindings() {
        keyboardMonitor.$triggerKeyEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.triggerController.handleTriggerKey(
                    isPressed: event.isPressed,
                    timestamp: event.timestamp
                )
            }
            .store(in: &cancellables)

        keyboardMonitor.$isShiftPressed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateOverlayHandsFreeVisualState()
            }
            .store(in: &cancellables)

        keyboardMonitor.$escapePressedSignal
            .dropFirst()
            .sink { [weak self] _ in
                self?.triggerController.abortRecording()
            }
            .store(in: &cancellables)

        keyboardMonitor.$isCapsLockOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                self?.cachedCapsLockIsOn = isOn
            }
            .store(in: &cancellables)

        modelDownloader.$modelReady
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard let self else { return }
                if isReady {
                    self.whisperService.warmup()
                } else {
                    self.whisperService.unloadModel()
                }
            }
            .store(in: &cancellables)

        modelDownloader.$parakeetModelReady
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard let self else { return }
                if isReady {
                    self.parakeetService.warmup()
                } else {
                    self.parakeetService.unloadModel()
                }
            }
            .store(in: &cancellables)
    }
}
