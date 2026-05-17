import AppKit
import Foundation
import KeyVoxCore

extension TranscriptionManager {
    func updateOverlayHandsFreeVisualState() {
        let isPreviewActive = state == .recording &&
            stopRequestedAt == nil &&
            !isLocked &&
            keyboardMonitor.isTriggerKeyPressed &&
            keyboardMonitor.isShiftPressed
        OverlayManager.shared.setHandsFreeLocked(isLocked)
        OverlayManager.shared.setHandsFreeModifierPreviewActive(isPreviewActive)
    }

    func playSound(named name: String) {
        guard appSettings.isSoundEnabled else { return }
        if let sound = NSSound(named: name) {
            sound.volume = Float(appSettings.soundVolume)
            sound.play()
        }
    }

    #if DEBUG
    func logTextTransformationSpeedProfile(_ result: DictationPipelineResult) {
        let duration = String(format: "%.3f", result.textTransformationDuration)
        let style = result.textTransformationStyleIdentifier ?? "none"
        let mode = result.textTransformationProcessingMode.map { " mode=\($0)" } ?? ""
        let chunkSummary = " style=\(style)\(mode) chunks=\(result.textTransformationChunkCount)"
        let finalTextSuffix = " finalText=\(escapedDebugText(result.finalText))"
        if let errorDescription = result.textTransformationErrorDescription {
            print(
                "3. Text transformation: \(duration)s " +
                "applied=false error=\(errorDescription)" +
                chunkSummary +
                finalTextSuffix
            )
        } else {
            print(
                "3. Text transformation: \(duration)s " +
                "applied=\(result.textTransformationApplied)" +
                chunkSummary +
                finalTextSuffix
            )
        }
    }

    func escapedDebugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    #endif
}
