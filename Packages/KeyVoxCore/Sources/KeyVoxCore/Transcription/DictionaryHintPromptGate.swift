import Foundation

public enum DictionaryHintPromptGate {
    public static func shouldUseHintPrompt(
        lastCaptureHadActiveSignal: Bool,
        lastCaptureWasLikelySilence: Bool,
        lastCaptureWasLongTrueSilence: Bool,
        lastCaptureDuration: TimeInterval,
        maxActiveSignalRunDuration: TimeInterval,
        minimumCaptureDuration: TimeInterval = 0.45,
        minimumActiveSignalRunDuration: TimeInterval = 0.35
    ) -> Bool {
        guard lastCaptureHadActiveSignal else { return false }
        guard !lastCaptureWasLikelySilence else { return false }
        guard !lastCaptureWasLongTrueSilence else { return false }
        guard lastCaptureDuration >= minimumCaptureDuration else { return false }
        guard maxActiveSignalRunDuration >= minimumActiveSignalRunDuration else { return false }
        return true
    }
}
