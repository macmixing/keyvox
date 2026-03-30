import Combine
import Foundation

enum SessionDisableTiming: String, CaseIterable, Identifiable {
    case immediately
    case fiveMinutes
    case fifteenMinutes
    case oneHour

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .fiveMinutes: return "5 Minutes"
        case .fifteenMinutes: return "15 Minutes"
        case .oneHour: return "1 Hour"
        }
    }

    var idleTimeout: TimeInterval? {
        switch self {
        case .immediately: return nil
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .oneHour: return 3600
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    enum ActiveDictationProvider: String, CaseIterable, Identifiable {
        case whisper
        case parakeet

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .whisper:
                return "Whisper Base"
            case .parakeet:
                return "Parakeet TDT v3"
            }
        }

        var modelID: DictationModelID {
            switch self {
            case .whisper:
                return .whisperBase
            case .parakeet:
                return .parakeetTdtV3
            }
        }

        var missingModelMessage: String {
            switch self {
            case .whisper:
                return "Whisper model not found."
            case .parakeet:
                return "Parakeet model not found."
            }
        }
    }

    enum TriggerBinding: String, CaseIterable, Identifiable {
        case rightOption
        case leftOption
        case rightCommand
        case leftCommand
        case rightControl
        case leftControl
        case function

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .leftOption: return "Left Option (⌥)"
            case .rightOption: return "Right Option (⌥)"
            case .leftCommand: return "Left Command (⌘)"
            case .rightCommand: return "Right Command (⌘)"
            case .leftControl: return "Left Control (⌃)"
            case .rightControl: return "Right Control (⌃)"
            case .function: return "Fn (Function)"
            }
        }
    }

    @Published var triggerBinding: TriggerBinding {
        didSet {
            defaults.set(triggerBinding.rawValue, forKey: UserDefaultsKeys.triggerBinding)
        }
    }

    @Published var autoParagraphsEnabled: Bool {
        didSet {
            defaults.set(autoParagraphsEnabled, forKey: UserDefaultsKeys.autoParagraphsEnabled)
        }
    }

    @Published var listFormattingEnabled: Bool {
        didSet {
            defaults.set(listFormattingEnabled, forKey: UserDefaultsKeys.listFormattingEnabled)
        }
    }

    @Published var capsLockEnabled: Bool {
        didSet {
            defaults.set(capsLockEnabled, forKey: UserDefaultsKeys.capsLockEnabled)
        }
    }

    @Published var keyboardHapticsEnabled: Bool {
        didSet {
            defaults.set(keyboardHapticsEnabled, forKey: UserDefaultsKeys.keyboardHapticsEnabled)
        }
    }

    @Published var preferBuiltInMicrophone: Bool {
        didSet {
            defaults.set(preferBuiltInMicrophone, forKey: UserDefaultsKeys.preferBuiltInMicrophone)
        }
    }

    @Published var liveActivitiesEnabled: Bool {
        didSet {
            defaults.set(liveActivitiesEnabled, forKey: UserDefaultsKeys.liveActivitiesEnabled)
        }
    }

    @Published var sessionDisableTiming: SessionDisableTiming {
        didSet {
            defaults.set(sessionDisableTiming.rawValue, forKey: UserDefaultsKeys.sessionDisableTiming)
        }
    }

    @Published var activeDictationProvider: ActiveDictationProvider {
        didSet {
            defaults.set(activeDictationProvider.rawValue, forKey: UserDefaultsKeys.App.activeDictationProvider)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: UserDefaultsKeys.triggerBinding),
           let binding = TriggerBinding(rawValue: raw) {
            triggerBinding = binding
        } else {
            triggerBinding = .rightOption
        }

        autoParagraphsEnabled = defaults.object(forKey: UserDefaultsKeys.autoParagraphsEnabled) as? Bool ?? true
        listFormattingEnabled = defaults.object(forKey: UserDefaultsKeys.listFormattingEnabled) as? Bool ?? true
        capsLockEnabled = defaults.object(forKey: UserDefaultsKeys.capsLockEnabled) as? Bool ?? false
        keyboardHapticsEnabled = defaults.object(forKey: UserDefaultsKeys.keyboardHapticsEnabled) as? Bool ?? true
        preferBuiltInMicrophone = defaults.object(forKey: UserDefaultsKeys.preferBuiltInMicrophone) as? Bool ?? true
        liveActivitiesEnabled = defaults.object(forKey: UserDefaultsKeys.liveActivitiesEnabled) as? Bool ?? true
        if let raw = defaults.string(forKey: UserDefaultsKeys.sessionDisableTiming),
           let timing = SessionDisableTiming(rawValue: raw) {
            sessionDisableTiming = timing
        } else {
            sessionDisableTiming = .fiveMinutes
        }

        if let raw = defaults.string(forKey: UserDefaultsKeys.App.activeDictationProvider),
           let provider = ActiveDictationProvider(rawValue: raw) {
            activeDictationProvider = provider
        } else {
            activeDictationProvider = .whisper
        }
    }

    func applyCloudTriggerBinding(_ value: TriggerBinding) {
        guard triggerBinding != value else { return }
        triggerBinding = value
    }

    func applyCloudAutoParagraphsEnabled(_ value: Bool) {
        guard autoParagraphsEnabled != value else { return }
        autoParagraphsEnabled = value
    }

    func applyCloudListFormattingEnabled(_ value: Bool) {
        guard listFormattingEnabled != value else { return }
        listFormattingEnabled = value
    }
}
