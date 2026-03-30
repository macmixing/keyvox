import Foundation
import Combine

@MainActor
final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()

    enum ActiveDictationProvider: String, CaseIterable, Identifiable {
        case whisper
        case parakeet

        var id: String { rawValue }

        var modelID: DictationModelID {
            switch self {
            case .whisper:
                return .whisperBase
            case .parakeet:
                return .parakeetTdtV3
            }
        }

        var displayName: String {
            switch self {
            case .whisper:
                return "Whisper"
            case .parakeet:
                return "Parakeet"
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

    @Published var pendingUpdatedVersion: String? {
        didSet {
            defaults.set(pendingUpdatedVersion, forKey: UserDefaultsKeys.App.pendingUpdatedVersion)
        }
    }

    @Published var lastAcknowledgedUpdatedVersion: String? {
        didSet {
            defaults.set(lastAcknowledgedUpdatedVersion, forKey: UserDefaultsKeys.App.lastAcknowledgedUpdatedVersion)
        }
    }

    @Published var activeDictationProvider: ActiveDictationProvider {
        didSet {
            defaults.set(activeDictationProvider.rawValue, forKey: UserDefaultsKeys.App.activeDictationProvider)
        }
    }

    private let defaults: UserDefaults
    private let defaultSoundVolume: Double = 0.1

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults

        hasCompletedOnboarding = defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)

        if let raw = defaults.string(forKey: UserDefaultsKeys.triggerBinding),
           let binding = TriggerBinding(rawValue: raw) {
            triggerBinding = binding
        } else {
            triggerBinding = .rightOption
        }

        autoParagraphsEnabled = defaults.object(forKey: UserDefaultsKeys.autoParagraphsEnabled) as? Bool ?? true
        listFormattingEnabled = defaults.object(forKey: UserDefaultsKeys.listFormattingEnabled) as? Bool ?? true

        isSoundEnabled = defaults.object(forKey: UserDefaultsKeys.isSoundEnabled) as? Bool ?? true
        if let storedVolume = defaults.object(forKey: UserDefaultsKeys.soundVolume) as? NSNumber {
            soundVolume = min(max(storedVolume.doubleValue, 0.0), 1.0)
        } else {
            soundVolume = defaultSoundVolume
        }

        selectedMicrophoneUID = defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""
        updateAlertLastShown = defaults.object(forKey: UserDefaultsKeys.App.updateAlertLastShown) as? Date
        updateAlertSnoozedUntil = defaults.object(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil) as? Date
        pendingUpdatedVersion = defaults.string(forKey: UserDefaultsKeys.App.pendingUpdatedVersion)
        lastAcknowledgedUpdatedVersion = defaults.string(forKey: UserDefaultsKeys.App.lastAcknowledgedUpdatedVersion)
        if let raw = defaults.string(forKey: UserDefaultsKeys.App.activeDictationProvider),
           let provider = ActiveDictationProvider(rawValue: raw) {
            activeDictationProvider = provider
        } else {
            activeDictationProvider = .whisper
        }
    }

    func refreshSelectedMicrophoneFromDefaults() {
        let persisted = defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""
        guard persisted != selectedMicrophoneUID else { return }
        selectedMicrophoneUID = persisted
    }

    func applyCloudAutoParagraphsEnabled(_ value: Bool) {
        guard autoParagraphsEnabled != value else { return }
        autoParagraphsEnabled = value
    }

    func applyCloudTriggerBinding(_ value: TriggerBinding) {
        guard triggerBinding != value else { return }
        triggerBinding = value
    }

    func applyCloudListFormattingEnabled(_ value: Bool) {
        guard listFormattingEnabled != value else { return }
        listFormattingEnabled = value
    }
}
