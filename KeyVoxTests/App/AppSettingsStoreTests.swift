import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class AppSettingsStoreTests: XCTestCase {
    func testInitUsesExpectedDefaultsWhenNoValuesPersisted() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)

        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { now })

        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertEqual(store.triggerBinding, .rightOption)
        XCTAssertTrue(store.autoParagraphsEnabled)
        XCTAssertTrue(store.listFormattingEnabled)
        XCTAssertTrue(store.isSoundEnabled)
        XCTAssertEqual(store.soundVolume, 0.1, accuracy: 0.0001)
        XCTAssertEqual(store.selectedMicrophoneUID, "")
        XCTAssertNil(store.updateAlertLastShown)
        XCTAssertNil(store.updateAlertSnoozedUntil)
        XCTAssertEqual(store.wordsThisWeek, 0)
        XCTAssertNotNil(defaults.object(forKey: UserDefaultsKeys.App.wordsThisWeekWeekStart))
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKeys.App.wordsThisWeekCount), 0)
    }

    func testInitHydratesPersistedValuesAndClampsStoredVolume() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let lastShown = makeDate(calendar: calendar, year: 2026, month: 2, day: 10)
        let snoozedUntil = makeDate(calendar: calendar, year: 2026, month: 2, day: 20)

        defaults.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        defaults.set(AppSettingsStore.TriggerBinding.leftCommand.rawValue, forKey: UserDefaultsKeys.triggerBinding)
        defaults.set(false, forKey: UserDefaultsKeys.autoParagraphsEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.listFormattingEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.isSoundEnabled)
        defaults.set(1.8, forKey: UserDefaultsKeys.soundVolume)
        defaults.set("mic-123", forKey: UserDefaultsKeys.selectedMicrophoneUID)
        defaults.set(lastShown, forKey: UserDefaultsKeys.App.updateAlertLastShown)
        defaults.set(snoozedUntil, forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil)
        defaults.set(currentWeekStart, forKey: UserDefaultsKeys.App.wordsThisWeekWeekStart)
        defaults.set(12, forKey: UserDefaultsKeys.App.wordsThisWeekCount)

        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { now })

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.triggerBinding, .leftCommand)
        XCTAssertFalse(store.autoParagraphsEnabled)
        XCTAssertFalse(store.listFormattingEnabled)
        XCTAssertFalse(store.isSoundEnabled)
        XCTAssertEqual(store.soundVolume, 1.0, accuracy: 0.0001)
        XCTAssertEqual(store.selectedMicrophoneUID, "mic-123")
        XCTAssertEqual(store.updateAlertLastShown, lastShown)
        XCTAssertEqual(store.updateAlertSnoozedUntil, snoozedUntil)
        XCTAssertEqual(store.wordsThisWeek, 12)
    }

    func testInitFallsBackToDefaultTriggerBindingForInvalidStoredValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)

        defaults.set("not-a-binding", forKey: UserDefaultsKeys.triggerBinding)
        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { now })

        XCTAssertEqual(store.triggerBinding, .rightOption)
    }

    func testSoundVolumeClampsOnWriteAndPersistsClampedValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)
        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { now })

        store.soundVolume = 2.5
        XCTAssertEqual(store.soundVolume, 1.0, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKeys.soundVolume), 1.0, accuracy: 0.0001)

        store.soundVolume = -0.25
        XCTAssertEqual(store.soundVolume, 0.0, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKeys.soundVolume), 0.0, accuracy: 0.0001)
    }

    func testRecordSpokenWordsAndWeeklyRollover() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let weekOneDate = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)
        let nextWeekDate = makeDate(calendar: calendar, year: 2026, month: 2, day: 24)
        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { weekOneDate })

        store.recordSpokenWords(from: "hello   world", at: weekOneDate)
        XCTAssertEqual(store.wordsThisWeek, 2)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKeys.App.wordsThisWeekCount), 2)

        store.recordSpokenWords(from: "     ", at: weekOneDate)
        XCTAssertEqual(store.wordsThisWeek, 2)

        store.refreshWeeklyWordCounterIfNeeded(referenceDate: nextWeekDate)
        XCTAssertEqual(store.wordsThisWeek, 0)
    }

    func testPropertyWritesPersistExpectedValues() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)
        let lastShown = makeDate(calendar: calendar, year: 2026, month: 2, day: 10)
        let snoozedUntil = makeDate(calendar: calendar, year: 2026, month: 2, day: 20)
        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { now })

        store.hasCompletedOnboarding = true
        store.triggerBinding = .rightCommand
        store.autoParagraphsEnabled = false
        store.listFormattingEnabled = false
        store.isSoundEnabled = false
        store.selectedMicrophoneUID = "usb-mic"
        store.updateAlertLastShown = lastShown
        store.updateAlertSnoozedUntil = snoozedUntil

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding))
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.triggerBinding), AppSettingsStore.TriggerBinding.rightCommand.rawValue)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.autoParagraphsEnabled) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.listFormattingEnabled) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.isSoundEnabled) as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID), "usb-mic")
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.App.updateAlertLastShown) as? Date, lastShown)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil) as? Date, snoozedUntil)
    }

    func testRefreshSelectedMicrophoneFromDefaultsHydratesExternalDefaultWrite() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 2, day: 17)
        let store = AppSettingsStore(defaults: defaults, calendar: calendar, now: { now })

        XCTAssertEqual(store.selectedMicrophoneUID, "")
        defaults.set("builtin-mic", forKey: UserDefaultsKeys.selectedMicrophoneUID)
        XCTAssertEqual(store.selectedMicrophoneUID, "")

        store.refreshSelectedMicrophoneFromDefaults()
        XCTAssertEqual(store.selectedMicrophoneUID, "builtin-mic")
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(
        calendar: Calendar,
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        )
        return components.date!
    }
}
