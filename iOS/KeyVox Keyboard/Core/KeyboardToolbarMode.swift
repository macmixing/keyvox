import Foundation

enum KeyboardToolbarMode: Equatable {
    case hidden
    case branded
    case dictationModelWarning
    case dictationModelActionWarning(String)
    case fullAccessWarning
    case microphoneWarning

    static func resolve(
        modelAvailability: KeyboardDictationModelStatus.Availability,
        hasFullAccess: Bool,
        hasMicrophonePermission: Bool
    ) -> KeyboardToolbarMode {
        switch modelAvailability {
        case .ready:
            break
        case .notInstalled:
            return .dictationModelWarning
        case .actionRequired(let message):
            return .dictationModelActionWarning(message)
        }

        guard hasFullAccess else {
            return .fullAccessWarning
        }

        guard hasMicrophonePermission else {
            return .microphoneWarning
        }

        return .branded
    }

    var warningText: String? {
        switch self {
        case .dictationModelWarning:
            return String(localized: "Install a dictation model", comment: "Warning shown in the keyboard toolbar when no dictation model is installed.")
        case .dictationModelActionWarning(let message):
            return message
        case .fullAccessWarning:
            return String(localized: "Allow Full Access for dictation", comment: "Warning shown in the keyboard toolbar when Full Access is off. Use Apple's official name for Full Access in this language.")
        case .microphoneWarning:
            return String(localized: "Allow Microphone Access for dictation", comment: "Warning shown in the keyboard toolbar when microphone permission is off.")
        case .hidden, .branded:
            return nil
        }
    }

    var showsWarningInfoButton: Bool {
        self == .fullAccessWarning
    }
}
