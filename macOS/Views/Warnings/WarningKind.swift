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
                return String(localized: "No microphone audio detected", comment: "Title of the warning panel shown near the dictation pill when the microphone sends no audio.")
            case .noSpeechDetected:
                return String(localized: "Didn't hear that!", comment: "Title of the warning panel shown near the dictation pill when no speech was detected.")
            }
        case .accessibilityPermission:
            return String(localized: "Accessibility access required", comment: "Title of the warning panel shown near the dictation pill when macOS Accessibility access is missing. Use the name macOS uses for Accessibility in this language.")
        case .modelMissing:
            return String(localized: "Model is not installed", comment: "Title of the warning panel shown near the dictation pill when no dictation model is installed.")
        case .modelUpdating:
            return String(localized: "Model is updating", comment: "Title of the warning panel shown near the dictation pill while the dictation model is updating.")
        }
    }

    var message: String {
        switch self {
        case .microphoneSilence(let reason, let microphoneName):
            let normalizedName = AudioSilenceGatePolicy.normalizedMicrophoneName(microphoneName)
            switch reason {
            case .muted:
                return String(localized: "Your \(normalizedName) mic may be muted. Check System Settings or switch the input device in KeyVox Settings.", comment: "Message of the warning panel shown near the dictation pill when the microphone sends no audio. %@ is the microphone's name. KeyVox Settings is the KeyVox settings window. System Settings is the macOS app; use the name macOS uses in this language. KeyVox is a brand name and stays in English.")
            case .noSpeechDetected:
                return String(localized: "KeyVox didn't pick up any speech from your \(normalizedName) microphone.", comment: "Message of the warning panel shown near the dictation pill when no speech was detected. %@ is the microphone's name. KeyVox is a brand name and stays in English.")
            }
        case .accessibilityPermission:
            return String(localized: "KeyVox needs Accessibility access to paste dictation into other apps. Enable it in System Settings, then try again.", comment: "Message of the warning panel shown near the dictation pill when macOS Accessibility access is missing. Use the name macOS uses for Accessibility in this language. System Settings is the macOS app; use the name macOS uses in this language. KeyVox is a brand name and stays in English.")
        case .modelMissing:
            return String(localized: "KeyVox needs a local Whisper model before dictation can start. Open KeyVox Settings to download it.", comment: "Message of the warning panel shown near the dictation pill when no dictation model is installed. KeyVox Settings is the KeyVox settings window. KeyVox and Whisper are brand names and stay in English.")
        case .modelUpdating:
            return String(localized: "Dictation will be available again as soon as the model update finishes.", comment: "Message of the warning panel shown near the dictation pill while the dictation model is updating.")
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
