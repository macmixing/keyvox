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

        #expect(defaults.string(forKey: iOSUserDefaultsKeys.triggerBinding) == iOSAppSettingsStore.TriggerBinding.leftControl.rawValue)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.autoParagraphsEnabled) as? Bool == false)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.listFormattingEnabled) as? Bool == false)
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

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "iOSAppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
