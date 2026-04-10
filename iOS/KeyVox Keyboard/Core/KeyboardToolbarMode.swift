import Foundation

enum KeyboardToolbarMode {
    case hidden
    case branded
    case fullAccessWarning
    case microphoneWarning
    case phoneCallWarning
    case updateRequiredWarning

    static func resolve(
        isModelInstalled: Bool,
        hasFullAccess: Bool,
        hasMicrophonePermission: Bool,
        hasActivePhoneCall: Bool,
        isUpdateRequired: Bool
    ) -> KeyboardToolbarMode {
        guard isModelInstalled else {
            return .hidden
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
