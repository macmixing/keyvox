import Foundation

public enum ParakeetError: Error, LocalizedError, Equatable {
    case initializationFailed
    case invalidFrames
    case transcriptionFailed(code: Int32, message: String?)
    case modelNotFound
    case runtimeUnavailable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return NSLocalizedString("Parakeet initialization failed.", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation error shown when the Parakeet speech model cannot start. Parakeet is a brand name and stays in English.")
        case .invalidFrames:
            return NSLocalizedString("Parakeet transcription requires non-empty audio frames.", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation error shown when no audio was recorded. Parakeet is a brand name and stays in English.")
        case let .transcriptionFailed(code, message):
            if let message, !message.isEmpty {
                return String(format: NSLocalizedString("Parakeet transcription failed (%d): %@", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation error shown when the Parakeet speech model fails. %d is a technical error number and %@ is the engine's own technical message. Parakeet is a brand name and stays in English."), code, message)
            }
            return String(format: NSLocalizedString("Parakeet transcription failed (%d).", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation error shown when the Parakeet speech model fails. %d is a technical error number. Parakeet is a brand name and stays in English."), code)
        case .modelNotFound:
            return NSLocalizedString("Parakeet model not found.", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation error shown when the Parakeet model files are missing. Parakeet is a brand name and stays in English.")
        case .runtimeUnavailable:
            return NSLocalizedString("Parakeet runtime is unavailable.", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation error shown when the Parakeet speech engine cannot run on this device. Parakeet is a brand name and stays in English.")
        case .cancelled:
            return NSLocalizedString("Parakeet transcription was cancelled.", bundle: KeyVoxParakeetLocalization.bundle, comment: "Dictation message shown when a Parakeet transcription was stopped before finishing. Parakeet is a brand name and stays in English.")
        }
    }
}
