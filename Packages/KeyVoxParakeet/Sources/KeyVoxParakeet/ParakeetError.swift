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
            return "Parakeet initialization failed."
        case .invalidFrames:
            return "Parakeet transcription requires non-empty audio frames."
        case let .transcriptionFailed(code, message):
            if let message, !message.isEmpty {
                return "Parakeet transcription failed (\(code)): \(message)"
            }
            return "Parakeet transcription failed (\(code))."
        case .modelNotFound:
            return "Parakeet model not found."
        case .runtimeUnavailable:
            return "Parakeet runtime is unavailable."
        case .cancelled:
            return "Parakeet transcription was cancelled."
        }
    }
}
