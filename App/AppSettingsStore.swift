import Foundation
import Combine

@MainActor
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

    @Published var wordsThisWeek: Int {
        didSet {
            defaults.set(wordsThisWeek, forKey: UserDefaultsKeys.App.wordsThisWeekCount)
        }
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private let defaultSoundVolume: Double = 0.1
    private var wordsThisWeekStart: Date

    // Keep teardown executor-agnostic to avoid runtime deinit crashes in test host.
    nonisolated deinit {}

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now

        let nowDate = now()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: nowDate)?.start ?? nowDate

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

        let storedWeekStart = defaults.object(forKey: UserDefaultsKeys.App.wordsThisWeekWeekStart) as? Date
        let storedCount = defaults.object(forKey: UserDefaultsKeys.App.wordsThisWeekCount) as? NSNumber
        if let storedWeekStart, calendar.isDate(storedWeekStart, inSameDayAs: currentWeekStart) {
            wordsThisWeekStart = storedWeekStart
            wordsThisWeek = max(0, storedCount?.intValue ?? 0)
        } else {
            wordsThisWeekStart = currentWeekStart
            wordsThisWeek = 0
            defaults.set(currentWeekStart, forKey: UserDefaultsKeys.App.wordsThisWeekWeekStart)
            defaults.set(0, forKey: UserDefaultsKeys.App.wordsThisWeekCount)
        }
    }

    func recordSpokenWords(from text: String, at date: Date? = nil) {
        let referenceDate = date ?? now()
        rolloverWordsCounterIfNeeded(referenceDate: referenceDate)

        let count = text
            .split(whereSeparator: \.isWhitespace)
            .count
        guard count > 0 else { return }

        wordsThisWeek += count
    }

    func refreshWeeklyWordCounterIfNeeded(referenceDate: Date? = nil) {
        let evaluatedDate = referenceDate ?? now()
        rolloverWordsCounterIfNeeded(referenceDate: evaluatedDate)
    }

    func refreshSelectedMicrophoneFromDefaults() {
        let persisted = defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""
        guard persisted != selectedMicrophoneUID else { return }
        selectedMicrophoneUID = persisted
    }

    private func rolloverWordsCounterIfNeeded(referenceDate: Date) {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        guard !calendar.isDate(wordsThisWeekStart, inSameDayAs: currentWeekStart) else {
            return
        }

        wordsThisWeekStart = currentWeekStart
        wordsThisWeek = 0
        defaults.set(currentWeekStart, forKey: UserDefaultsKeys.App.wordsThisWeekWeekStart)
    }
}
