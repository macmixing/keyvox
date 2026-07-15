import Foundation

enum KeyboardToolbarMode: Equatable {
    case hidden
    case branded
    case dictationModelWarning
    case dictationModelActionWarning(String)
    case fullAccessWarning
    case microphoneWarning
    case phoneCallWarning
    case updateRequiredWarning

    static func resolve(
        modelAvailability: KeyboardDictationModelStatus.Availability,
        hasFullAccess: Bool,
        hasMicrophonePermission: Bool,
        hasActivePhoneCall: Bool,
        isUpdateRequired: Bool
    ) -> KeyboardToolbarMode {
        switch modelAvailability {
        case .ready:
            break
        case .notInstalled:
            return .dictationModelWarning
        case .actionRequired(let message):
            return .dictationModelActionWarning(message)
        }

        guard isUpdateRequired == false else {
            return .updateRequiredWarning
        }

        guard hasFullAccess else {
            return .fullAccessWarning
        }

        guard hasMicrophonePermission else {
            return .microphoneWarning
        }

        guard hasActivePhoneCall == false else {
            return .phoneCallWarning
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
        case .phoneCallWarning:
            return "Use KeyVox after this call"
        case .updateRequiredWarning:
            return "Update KeyVox to keep using dictation"
        case .hidden, .branded:
            return nil
        }
    }

    var showsWarningInfoButton: Bool {
        self == .fullAccessWarning
    }
}
