import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSAppSettingsStoreTests {
    @Test func valuesPersistToDefaults() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        store.triggerBinding = .leftControl
        store.autoParagraphsEnabled = false
        store.listFormattingEnabled = false
        store.capsLockEnabled = true
        store.keyboardHapticsEnabled = false
        store.preferBuiltInMicrophone = false
        store.sessionDisableTiming = .oneHour

        #expect(defaults.string(forKey: iOSUserDefaultsKeys.triggerBinding) == iOSAppSettingsStore.TriggerBinding.leftControl.rawValue)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.autoParagraphsEnabled) as? Bool == false)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.listFormattingEnabled) as? Bool == false)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.capsLockEnabled) as? Bool == true)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.keyboardHapticsEnabled) as? Bool == false)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.preferBuiltInMicrophone) as? Bool == false)
        #expect(defaults.string(forKey: iOSUserDefaultsKeys.sessionDisableTiming) == iOSSessionDisableTiming.oneHour.rawValue)
    }

    @Test func triggerBindingRoundTripsThroughRawValue() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(iOSAppSettingsStore.TriggerBinding.leftCommand.rawValue, forKey: iOSUserDefaultsKeys.triggerBinding)

        let store = iOSAppSettingsStore(defaults: defaults)

        #expect(store.triggerBinding == .leftCommand)
    }

    @Test func applyCloudTriggerBindingUpdatesOnlyWhenNeeded() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        store.applyCloudTriggerBinding(.leftOption)
        #expect(store.triggerBinding == .leftOption)

        store.applyCloudTriggerBinding(.leftOption)
        #expect(store.triggerBinding == .leftOption)
    }

    @Test func applyCloudAutoParagraphsEnabledUpdatesOnlyWhenNeeded() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        store.applyCloudAutoParagraphsEnabled(false)
        #expect(store.autoParagraphsEnabled == false)

        store.applyCloudAutoParagraphsEnabled(false)
        #expect(store.autoParagraphsEnabled == false)
    }

    @Test func applyCloudListFormattingEnabledUpdatesOnlyWhenNeeded() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        store.applyCloudListFormattingEnabled(false)
        #expect(store.listFormattingEnabled == false)

        store.applyCloudListFormattingEnabled(false)
        #expect(store.listFormattingEnabled == false)
    }

    @Test func capsLockEnabledDefaultsToFalseAndRoundTripsThroughDefaults() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        #expect(store.capsLockEnabled == false)

        store.capsLockEnabled = true

        let reloaded = iOSAppSettingsStore(defaults: defaults)
        #expect(reloaded.capsLockEnabled == true)
    }

    @Test func preferBuiltInMicrophoneDefaultsToTrueAndRoundTripsThroughDefaults() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        #expect(store.preferBuiltInMicrophone == true)

        store.preferBuiltInMicrophone = false

        let reloaded = iOSAppSettingsStore(defaults: defaults)
        #expect(reloaded.preferBuiltInMicrophone == false)
    }

    @Test func keyboardHapticsEnabledDefaultsToTrueAndRoundTripsThroughDefaults() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        #expect(store.keyboardHapticsEnabled == true)

        store.keyboardHapticsEnabled = false

        let reloaded = iOSAppSettingsStore(defaults: defaults)
        #expect(reloaded.keyboardHapticsEnabled == false)
    }

    @Test func sessionDisableTimingDefaultsToFiveMinutesAndRoundTripsThroughDefaults() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = iOSAppSettingsStore(defaults: defaults)
        #expect(store.sessionDisableTiming == .fiveMinutes)

        store.sessionDisableTiming = .immediately

        let reloaded = iOSAppSettingsStore(defaults: defaults)
        #expect(reloaded.sessionDisableTiming == .immediately)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "iOSAppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
