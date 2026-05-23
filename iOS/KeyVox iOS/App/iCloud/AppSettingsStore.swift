import Combine
import CoreFoundation
import Foundation
import KeyVoxStyleRewrite

enum SessionDisableTiming: String, CaseIterable, Identifiable {
    case immediately
    case fiveMinutes
    case fifteenMinutes
    case oneHour
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .fiveMinutes: return "5 Minutes"
        case .fifteenMinutes: return "15 Minutes"
        case .oneHour: return "1 Hour"
        case .never: return "Never"
        }
    }
    /// Returns the idle timeout before disabling, or `nil` if no timeout applies.
    /// When `nil`, check `keepsSessionActiveIndefinitely` to distinguish
    /// between immediate disable (`.immediately`) and never disable (`.never`)
    var idleTimeout: TimeInterval? {
        switch self {
        case .immediately, .never: return nil
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .oneHour: return 3600
        }
    }

    var keepsSessionActiveIndefinitely: Bool {
        self == .never
    }
}

enum SpeakTimeoutTiming: String, CaseIterable, Identifiable {
    case immediately
    case fiveMinutes
    case fifteenMinutes
    case oneHour
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .fiveMinutes: return "5 Minutes"
        case .fifteenMinutes: return "15 Minutes"
        case .oneHour: return "1 Hour"
        case .never: return "Never"
        }
    }
    /// Returns the delay before unloading, or `nil` if no delay applies.
    /// When `nil`, check `keepsRuntimeWarmIndefinitely` to distinguish
    /// between immediate unload (`.immediately`) and never unload (`.never`)
    var unloadDelay: TimeInterval? {
        switch self {
        case .immediately, .never: return nil
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .oneHour: return 3600
        }
    }

    /// Returns `true` when the runtime should remain warm without timeout.
    var keepsRuntimeWarmIndefinitely: Bool {
        self == .never
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    private static let darwinNotificationCallback: CFNotificationCallback = { _, observer, name, _, _ in
        guard let observer,
              let notificationName = name?.rawValue as String? else {
            return
        }

        let store = Unmanaged<AppSettingsStore>.fromOpaque(observer).takeUnretainedValue()
        DispatchQueue.main.async {
            switch notificationName {
            case KeyVoxIPCBridge.Notification.vibeSelectionChanged:
                store.refreshSelectedVibeFromDefaults()
            case KeyVoxIPCBridge.Notification.listFormattingChanged:
                store.refreshListFormattingFromDefaults()
            case KeyVoxIPCBridge.Notification.autoParagraphsChanged:
                store.refreshAutoParagraphsFromDefaults()
            default:
                break
            }
        }
    }

    typealias TTSVoice = KeyVoxPlaybackVoice

    enum ActiveDictationProvider: String, CaseIterable, Identifiable {
        case whisper
        case parakeet

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .whisper:
                return "Whisper Base"
            case .parakeet:
                return "Parakeet v3"
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

        var styleRewriteDictationModel: StyleRewriteDictationModel {
            switch self {
            case .whisper:
                return .whisper
            case .parakeet:
                return .parakeet
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

    @Published var leftHandedKeyboardLayoutEnabled: Bool {
        didSet {
            defaults.set(leftHandedKeyboardLayoutEnabled, forKey: UserDefaultsKeys.leftHandedKeyboardLayoutEnabled)
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

    @Published var speakTimeoutTiming: SpeakTimeoutTiming {
        didSet {
            defaults.set(speakTimeoutTiming.rawValue, forKey: UserDefaultsKeys.speakTimeoutTiming)
        }
    }

    @Published var ttsVoice: TTSVoice {
        didSet {
            defaults.set(ttsVoice.rawValue, forKey: UserDefaultsKeys.ttsVoice)
        }
    }

    @Published var activeDictationProvider: ActiveDictationProvider {
        didSet {
            defaults.set(activeDictationProvider.rawValue, forKey: UserDefaultsKeys.App.activeDictationProvider)
        }
    }

    @Published var fastPlaybackModeEnabled: Bool {
        didSet {
            defaults.set(fastPlaybackModeEnabled, forKey: UserDefaultsKeys.fastPlaybackModeEnabled)
        }
    }

    @Published var selectedVibe: StyleRewriteStyle {
        didSet {
            defaults.set(selectedVibe.rawValue, forKey: UserDefaultsKeys.selectedVibe)
        }
    }

    private let defaults: UserDefaults
    private let canUseVibesProvider: () -> Bool
    private var observesKeyboardSettingChanges = false

    init(
        defaults: UserDefaults,
        canUseVibesProvider: @escaping () -> Bool = { true }
    ) {
        self.defaults = defaults
        self.canUseVibesProvider = canUseVibesProvider

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
        leftHandedKeyboardLayoutEnabled = defaults.object(forKey: UserDefaultsKeys.leftHandedKeyboardLayoutEnabled) as? Bool ?? false
        preferBuiltInMicrophone = defaults.object(forKey: UserDefaultsKeys.preferBuiltInMicrophone) as? Bool ?? true
        liveActivitiesEnabled = defaults.object(forKey: UserDefaultsKeys.liveActivitiesEnabled) as? Bool ?? true
        if let raw = defaults.string(forKey: UserDefaultsKeys.sessionDisableTiming),
           let timing = SessionDisableTiming(rawValue: raw) {
            sessionDisableTiming = timing
        } else {
            sessionDisableTiming = .fiveMinutes
        }

        if let raw = defaults.string(forKey: UserDefaultsKeys.speakTimeoutTiming),
           let timing = SpeakTimeoutTiming(rawValue: raw) {
            speakTimeoutTiming = timing
        } else {
            speakTimeoutTiming = .fiveMinutes
        }

        if let raw = defaults.string(forKey: UserDefaultsKeys.ttsVoice),
           let voice = TTSVoice(rawValue: raw) {
            ttsVoice = voice
        } else {
            ttsVoice = .alba
        }

        if let raw = defaults.string(forKey: UserDefaultsKeys.App.activeDictationProvider),
           let provider = ActiveDictationProvider(rawValue: raw) {
            activeDictationProvider = provider
        } else {
            activeDictationProvider = .whisper
        }

        fastPlaybackModeEnabled = defaults.object(forKey: UserDefaultsKeys.fastPlaybackModeEnabled) as? Bool ?? false
        selectedVibe = Self.resolvedSelectedVibe(
            from: defaults,
            canUseVibes: canUseVibesProvider()
        )
        if defaults.string(forKey: UserDefaultsKeys.selectedVibe) != selectedVibe.rawValue {
            defaults.set(selectedVibe.rawValue, forKey: UserDefaultsKeys.selectedVibe)
        }
        registerKeyboardSettingObservers()
    }

    deinit {
        guard observesKeyboardSettingChanges else { return }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    nonisolated static func resolvedSelectedVibe(
        from defaults: UserDefaults,
        canUseVibes: Bool
    ) -> StyleRewriteStyle {
        guard canUseVibes else {
            return .none
        }

        if let raw = defaults.string(forKey: UserDefaultsKeys.selectedVibe),
           let style = StyleRewriteStyle(rawValue: raw) {
            return style
        }

        return .none
    }

    func refreshSelectedVibeFromDefaults() {
        let style = Self.resolvedSelectedVibe(
            from: defaults,
            canUseVibes: canUseVibesProvider()
        )
        guard selectedVibe != style else { return }
        selectedVibe = style
    }

    func refreshListFormattingFromDefaults() {
        let isEnabled = defaults.object(forKey: UserDefaultsKeys.listFormattingEnabled) as? Bool ?? true
        guard listFormattingEnabled != isEnabled else { return }
        listFormattingEnabled = isEnabled
    }

    func refreshAutoParagraphsFromDefaults() {
        let isEnabled = defaults.object(forKey: UserDefaultsKeys.autoParagraphsEnabled) as? Bool ?? true
        guard autoParagraphsEnabled != isEnabled else { return }
        autoParagraphsEnabled = isEnabled
    }

    private func registerKeyboardSettingObservers() {
        guard observesKeyboardSettingChanges == false else { return }
        observesKeyboardSettingChanges = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        [
            KeyVoxIPCBridge.Notification.vibeSelectionChanged,
            KeyVoxIPCBridge.Notification.listFormattingChanged,
            KeyVoxIPCBridge.Notification.autoParagraphsChanged,
        ].forEach { notificationName in
            CFNotificationCenterAddObserver(
                center,
                Unmanaged.passUnretained(self).toOpaque(),
                Self.darwinNotificationCallback,
                notificationName as CFString,
                nil,
                .deliverImmediately
            )
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
