import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()

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

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        }
    }

    @Published var triggerBinding: TriggerBinding {
        didSet {
            defaults.set(triggerBinding.rawValue, forKey: UserDefaultsKeys.triggerBinding)
        }
    }

    @Published var isSoundEnabled: Bool {
        didSet {
            defaults.set(isSoundEnabled, forKey: UserDefaultsKeys.isSoundEnabled)
        }
    }

    @Published var soundVolume: Double {
        didSet {
            let clamped = min(max(soundVolume, 0.0), 1.0)
            if clamped != soundVolume {
                soundVolume = clamped
                return
            }
            defaults.set(soundVolume, forKey: UserDefaultsKeys.soundVolume)
        }
    }

    @Published var selectedMicrophoneUID: String {
        didSet {
            defaults.set(selectedMicrophoneUID, forKey: UserDefaultsKeys.selectedMicrophoneUID)
        }
    }

    @Published var updateAlertLastShown: Date? {
        didSet {
            defaults.set(updateAlertLastShown, forKey: UserDefaultsKeys.App.updateAlertLastShown)
        }
    }

    @Published var updateAlertSnoozedUntil: Date? {
        didSet {
            defaults.set(updateAlertSnoozedUntil, forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil)
        }
    }

    private let defaults = UserDefaults.standard
    private let defaultSoundVolume: Double = 0.1

    private init() {
        hasCompletedOnboarding = defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)

        if let raw = defaults.string(forKey: UserDefaultsKeys.triggerBinding),
           let binding = KeyboardMonitor.TriggerBinding(rawValue: raw) {
            triggerBinding = binding
        } else {
            triggerBinding = .rightOption
        }

        isSoundEnabled = defaults.object(forKey: UserDefaultsKeys.isSoundEnabled) as? Bool ?? true
        if let storedVolume = defaults.object(forKey: UserDefaultsKeys.soundVolume) as? NSNumber {
            soundVolume = min(max(storedVolume.doubleValue, 0.0), 1.0)
        } else {
            soundVolume = defaultSoundVolume
        }

        selectedMicrophoneUID = defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""
        updateAlertLastShown = defaults.object(forKey: UserDefaultsKeys.App.updateAlertLastShown) as? Date
        updateAlertSnoozedUntil = defaults.object(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil) as? Date
    }
}
