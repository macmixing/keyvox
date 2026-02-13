import Foundation

public enum WhisperError: Error, LocalizedError {
    case initializationFailed
    case invalidFrames
    case transcriptionFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize Whisper context"
        case .invalidFrames:
            return "Audio frames are empty"
        case .transcriptionFailed(let code):
            return "Whisper transcription failed with error code \(code)"
        }
    }
}
