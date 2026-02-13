import Foundation

enum WarningKind {
    case microphoneSilence
    case accessibilityPermission
    case modelMissing

    var iconName: String {
        switch self {
        case .microphoneSilence:
            return "mic.slash.fill"
        case .accessibilityPermission:
            return "accessibility"
        case .modelMissing:
            return "cpu"
        }
    }

    var title: String {
        switch self {
        case .microphoneSilence:
            return "No microphone audio detected"
        case .accessibilityPermission:
            return "Accessibility access required"
        case .modelMissing:
            return "Model is not installed"
        }
    }

    var message: String {
        switch self {
        case .microphoneSilence:
            return "Your microphone may be muted. Check System Settings or switch the input device in KeyVox Settings."
        case .accessibilityPermission:
            return "KeyVox needs Accessibility access to paste dictation into other apps. Enable it in System Settings, then try again."
        case .modelMissing:
            return "KeyVox needs a local Whisper model before dictation can start. Open KeyVox Settings to download it."
        }
    }

    var settingsTab: SettingsTab {
        switch self {
        case .microphoneSilence:
            return .audio
        case .accessibilityPermission:
            return .general
        case .modelMissing:
            return .model
        }
    }

    var systemSettingsURL: URL? {
        switch self {
        case .microphoneSilence:
            return URL(string: "x-apple.systempreferences:com.apple.preference.sound?Input")
        case .accessibilityPermission:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .modelMissing:
            return nil
        }
    }

    var showsKeyVoxSettingsButton: Bool {
        switch self {
        case .microphoneSilence, .modelMissing:
            return true
        case .accessibilityPermission:
            return false
        }
    }
}
