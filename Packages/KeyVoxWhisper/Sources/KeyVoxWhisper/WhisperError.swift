import Foundation

public enum WhisperError: Error, LocalizedError, Equatable {
    case initializationFailed
    case invalidFrames
    case transcriptionFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return NSLocalizedString("Failed to initialize Whisper context", bundle: KeyVoxWhisperLocalization.bundle, comment: "Dictation error shown when the Whisper speech model cannot start. Whisper is a brand name and stays in English.")
        case .invalidFrames:
            return NSLocalizedString("Audio frames are empty", bundle: KeyVoxWhisperLocalization.bundle, comment: "Dictation error shown when no audio was recorded.")
        case .transcriptionFailed(let code):
            return String(format: NSLocalizedString("Whisper transcription failed with error code %d", bundle: KeyVoxWhisperLocalization.bundle, comment: "Dictation error shown when the Whisper speech model fails. %d is a technical error number. Whisper is a brand name and stays in English."), code)
        }
    }
}
