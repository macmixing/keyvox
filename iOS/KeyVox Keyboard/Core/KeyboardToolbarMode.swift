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
            return "Install a dictation model"
        case .dictationModelActionWarning(let message):
            return message
        case .fullAccessWarning:
            return "Allow Full Access for dictation"
        case .microphoneWarning:
            return "Allow Microphone Access for dictation"
        case .hidden, .branded:
            return nil
        }
    }

    var showsWarningInfoButton: Bool {
        self == .fullAccessWarning
    }
}
