import Foundation

enum KeyboardToolbarMode {
    case hidden
    case branded
    case fullAccessWarning
    case microphoneWarning

    var warningText: String? {
        switch self {
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
