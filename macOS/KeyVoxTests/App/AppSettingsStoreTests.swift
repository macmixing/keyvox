import Foundation
import XCTest
import KeyVoxCore
import KeyVoxStyleRewrite
@testable import KeyVox

@MainActor
final class AppSettingsStoreTests: XCTestCase {
    func testInitUsesExpectedDefaultsWhenNoValuesPersisted() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(store.hasCompletedFirstDictation)
        XCTAssertFalse(store.hasSkippedFirstDictation)
        XCTAssertEqual(store.triggerBinding, .rightOption)
        XCTAssertTrue(store.autoParagraphsEnabled)
        XCTAssertTrue(store.listFormattingEnabled)
        XCTAssertTrue(store.isSoundEnabled)
        XCTAssertEqual(store.soundVolume, 0.1, accuracy: 0.0001)
        XCTAssertEqual(store.selectedMicrophoneUID, "")
        XCTAssertNil(store.updateAlertLastShown)
        XCTAssertNil(store.updateAlertSnoozedUntil)
        XCTAssertEqual(store.activeDictationProvider, .whisper)
        XCTAssertEqual(store.whisperDictationLanguage, .automatic)
        XCTAssertEqual(store.selectedVibe, .none)
        XCTAssertTrue(store.vibesTriggerKeyInteractionsEnabled)
        XCTAssertFalse(store.hideDockIconWhenAllWindowsClosed)
    }

    func testInitHydratesPersistedValuesAndClampsStoredVolume() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let lastShown = makeDate(year: 2026, month: 2, day: 10)
        let snoozedUntil = makeDate(year: 2026, month: 2, day: 20)

        defaults.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        defaults.set(true, forKey: UserDefaultsKeys.App.hasCompletedFirstDictation)
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSkippedFirstDictation)
        defaults.set(AppSettingsStore.TriggerBinding.leftCommand.rawValue, forKey: UserDefaultsKeys.triggerBinding)
        defaults.set(false, forKey: UserDefaultsKeys.autoParagraphsEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.listFormattingEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.isSoundEnabled)
        defaults.set(1.8, forKey: UserDefaultsKeys.soundVolume)
        defaults.set("mic-123", forKey: UserDefaultsKeys.selectedMicrophoneUID)
        defaults.set(lastShown, forKey: UserDefaultsKeys.App.updateAlertLastShown)
        defaults.set(snoozedUntil, forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil)
        defaults.set(AppSettingsStore.ActiveDictationProvider.parakeet.rawValue, forKey: UserDefaultsKeys.App.activeDictationProvider)
        defaults.set("es", forKey: UserDefaultsKeys.App.whisperDictationLanguage)
        defaults.set(StyleRewriteStyle.chill.rawValue, forKey: UserDefaultsKeys.selectedVibe)
        defaults.set(false, forKey: UserDefaultsKeys.vibesTriggerKeyInteractionsEnabled)
        defaults.set(true, forKey: UserDefaultsKeys.hideDockIconWhenAllWindowsClosed)

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(store.hasCompletedFirstDictation)
        XCTAssertTrue(store.hasSkippedFirstDictation)
        XCTAssertEqual(store.triggerBinding, .leftCommand)
        XCTAssertFalse(store.autoParagraphsEnabled)
        XCTAssertFalse(store.listFormattingEnabled)
        XCTAssertFalse(store.isSoundEnabled)
        XCTAssertEqual(store.soundVolume, 1.0, accuracy: 0.0001)
        XCTAssertEqual(store.selectedMicrophoneUID, "mic-123")
        XCTAssertEqual(store.updateAlertLastShown, lastShown)
        XCTAssertEqual(store.updateAlertSnoozedUntil, snoozedUntil)
        XCTAssertEqual(store.activeDictationProvider, .parakeet)
        XCTAssertEqual(store.whisperDictationLanguage, DictationLanguage(rawValue: "es"))
        XCTAssertEqual(store.selectedVibe, .chill)
        XCTAssertFalse(store.vibesTriggerKeyInteractionsEnabled)
        XCTAssertTrue(store.hideDockIconWhenAllWindowsClosed)
    }

    func testInitFallsBackToWhisperWhenPersistedParakeetIsUnsupportedOnCurrentOS() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(AppSettingsStore.ActiveDictationProvider.parakeet.rawValue, forKey: UserDefaultsKeys.App.activeDictationProvider)

        let store = AppSettingsStore(
            defaults: defaults,
            osVersion: OperatingSystemVersion(majorVersion: 13, minorVersion: 7, patchVersion: 0)
        )

        XCTAssertEqual(store.activeDictationProvider, .whisper)
    }

    func testInitFallsBackToDefaultTriggerBindingForInvalidStoredValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("not-a-binding", forKey: UserDefaultsKeys.triggerBinding)
        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.triggerBinding, .rightOption)
    }

    func testSoundVolumeClampsOnWriteAndPersistsClampedValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        store.soundVolume = 2.5
        XCTAssertEqual(store.soundVolume, 1.0, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKeys.soundVolume), 1.0, accuracy: 0.0001)

        store.soundVolume = -0.25
        XCTAssertEqual(store.soundVolume, 0.0, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKeys.soundVolume), 0.0, accuracy: 0.0001)
    }

    func testPropertyWritesPersistExpectedValues() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let lastShown = makeDate(year: 2026, month: 2, day: 10)
        let snoozedUntil = makeDate(year: 2026, month: 2, day: 20)
        let store = AppSettingsStore(defaults: defaults)

        store.hasCompletedOnboarding = true
        store.hasCompletedFirstDictation = true
        store.hasSkippedFirstDictation = true
        store.triggerBinding = .rightCommand
        store.autoParagraphsEnabled = false
        store.listFormattingEnabled = false
        store.isSoundEnabled = false
        store.selectedMicrophoneUID = "usb-mic"
        store.selectedVibe = .casual
        store.vibesTriggerKeyInteractionsEnabled = false
        store.hideDockIconWhenAllWindowsClosed = true
        store.updateAlertLastShown = lastShown
        store.updateAlertSnoozedUntil = snoozedUntil
        store.activeDictationProvider = .parakeet
        store.whisperDictationLanguage = DictationLanguage(rawValue: "fr")

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding))
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.App.hasCompletedFirstDictation))
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.App.hasSkippedFirstDictation))
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.triggerBinding), AppSettingsStore.TriggerBinding.rightCommand.rawValue)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.autoParagraphsEnabled) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.listFormattingEnabled) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.isSoundEnabled) as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID), "usb-mic")
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedVibe), StyleRewriteStyle.casual.rawValue)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.vibesTriggerKeyInteractionsEnabled) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.hideDockIconWhenAllWindowsClosed) as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.App.updateAlertLastShown) as? Date, lastShown)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil) as? Date, snoozedUntil)
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.App.activeDictationProvider), AppSettingsStore.ActiveDictationProvider.parakeet.rawValue)
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.App.whisperDictationLanguage), "fr")
    }

    func testInitFallsBackToAutomaticForUnsupportedWhisperLanguage() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unknown", forKey: UserDefaultsKeys.App.whisperDictationLanguage)

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.whisperDictationLanguage, .automatic)
    }

    func testSettingUnsupportedParakeetProviderFallsBackToWhisper() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(
            defaults: defaults,
            osVersion: OperatingSystemVersion(majorVersion: 13, minorVersion: 7, patchVersion: 0)
        )

        store.activeDictationProvider = .parakeet

        XCTAssertEqual(store.activeDictationProvider, .whisper)
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.App.activeDictationProvider), AppSettingsStore.ActiveDictationProvider.whisper.rawValue)
    }

    func testRefreshSelectedMicrophoneFromDefaultsHydratesExternalDefaultWrite() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.selectedMicrophoneUID, "")
        defaults.set("builtin-mic", forKey: UserDefaultsKeys.selectedMicrophoneUID)
        XCTAssertEqual(store.selectedMicrophoneUID, "")

        store.refreshSelectedMicrophoneFromDefaults()
        XCTAssertEqual(store.selectedMicrophoneUID, "builtin-mic")
    }

    func testApplyCloudAutoParagraphsEnabledPersistsValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        store.applyCloudAutoParagraphsEnabled(false)

        XCTAssertFalse(store.autoParagraphsEnabled)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.autoParagraphsEnabled) as? Bool, false)
    }

    func testApplyCloudTriggerBindingPersistsValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        store.applyCloudTriggerBinding(.leftControl)

        XCTAssertEqual(store.triggerBinding, .leftControl)
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.triggerBinding), AppSettingsStore.TriggerBinding.leftControl.rawValue)
    }

    func testApplyCloudListFormattingEnabledPersistsValue() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        store.applyCloudListFormattingEnabled(false)

        XCTAssertFalse(store.listFormattingEnabled)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKeys.listFormattingEnabled) as? Bool, false)
    }

    func testActiveDictationProviderMapsToExpectedModelID() {
        XCTAssertEqual(AppSettingsStore.ActiveDictationProvider.whisper.modelID, .whisperBase)
        XCTAssertEqual(AppSettingsStore.ActiveDictationProvider.parakeet.modelID, .parakeetTdtV3)
    }

    func testSelectedVibeHydratesWithoutAvailabilityGate() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(StyleRewriteStyle.polished.rawValue, forKey: UserDefaultsKeys.selectedVibe)

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.selectedVibe, .polished)
    }

    func testAdvanceSelectedVibeCycles() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.advanceSelectedVibe(), .casual)
        XCTAssertEqual(store.advanceSelectedVibe(), .polished)
        XCTAssertEqual(store.advanceSelectedVibe(), .chill)
        XCTAssertEqual(store.advanceSelectedVibe(), .none)
    }

    func testAdvanceSelectedVibeDoesNotDependOnAvailability() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)
        store.selectedVibe = .chill

        XCTAssertEqual(store.advanceSelectedVibe(), .none)
        XCTAssertEqual(store.selectedVibe, .none)
    }

    func testActiveDictationProviderSupportedCasesHideParakeetOnVentura() {
        let ventura = OperatingSystemVersion(majorVersion: 13, minorVersion: 7, patchVersion: 0)
        let sonoma = OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)

        XCTAssertEqual(AppSettingsStore.ActiveDictationProvider.supportedCases(osVersion: ventura), [.whisper])
        XCTAssertEqual(AppSettingsStore.ActiveDictationProvider.supportedCases(osVersion: sonoma), [.whisper, .parakeet])
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ).date!
    }
}
