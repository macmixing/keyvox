import Foundation
import KeyVoxCore

enum MicrophoneSilenceReason {
    case muted
    case noSpeechDetected
}

enum WarningKind {
    case microphoneSilence(reason: MicrophoneSilenceReason, microphoneName: String)
    case accessibilityPermission
    case modelMissing
    case modelUpdating

    var iconName: String {
        switch self {
        case .microphoneSilence:
            return "mic.slash.fill"
        case .accessibilityPermission:
            return "accessibility"
        case .modelMissing:
            return "cpu"
        case .modelUpdating:
            return "arrow.down.circle"
        }
    }

    var title: String {
        switch self {
        case .microphoneSilence(let reason, _):
            switch reason {
            case .muted:
                return "No microphone audio detected"
            case .noSpeechDetected:
                return "Didn't hear that!"
            }
        case .accessibilityPermission:
            return "Accessibility access required"
        case .modelMissing:
            return "Model is not installed"
        case .modelUpdating:
            return "Model is updating"
        }
    }

    var message: String {
        switch self {
        case .microphoneSilence(let reason, let microphoneName):
            let normalizedName = AudioSilenceGatePolicy.normalizedMicrophoneName(microphoneName)
            switch reason {
            case .muted:
                return "Your \(normalizedName) mic may be muted. Check System Settings or switch the input device in KeyVox Settings."
            case .noSpeechDetected:
                return "KeyVox didn't pick up any speech from your \(normalizedName) microphone."
            }
        case .accessibilityPermission:
            return "KeyVox needs Accessibility access to paste dictation into other apps. Enable it in System Settings, then try again."
        case .modelMissing:
            return "KeyVox needs a local Whisper model before dictation can start. Open KeyVox Settings to download it."
        case .modelUpdating:
            return "Dictation will be available again as soon as the model update finishes."
        }
    }

    var settingsTab: SettingsTab {
        switch self {
        case .microphoneSilence:
            return .settings
        case .accessibilityPermission:
            return .home
        case .modelMissing, .modelUpdating:
            return .settings
        }
    }

    var systemSettingsURL: URL? {
        switch self {
        case .microphoneSilence:
            return URL(string: "x-apple.systempreferences:com.apple.preference.sound?Input")
        case .accessibilityPermission:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .modelMissing, .modelUpdating:
            return nil
        }
    }

    var showsKeyVoxSettingsButton: Bool {
        switch self {
        case .microphoneSilence, .modelMissing:
            return true
        case .accessibilityPermission, .modelUpdating:
            return false
        }
    }
}
