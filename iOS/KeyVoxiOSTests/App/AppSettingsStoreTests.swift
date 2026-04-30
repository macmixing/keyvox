import Foundation
import KeyVoxStyleRewrite
import Testing
@testable import KeyVox_iOS

@MainActor
struct AppSettingsStoreTests {
    @Test func activeDictationProviderDefaultsToWhisper() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.activeDictationProvider == .whisper)
    }

    @Test func activeDictationProviderRestoresPersistedValue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(
            AppSettingsStore.ActiveDictationProvider.parakeet.rawValue,
            forKey: UserDefaultsKeys.App.activeDictationProvider
        )

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.activeDictationProvider == .parakeet)
    }

    @Test func activeDictationProviderWritesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AppSettingsStore(defaults: defaults)

        store.activeDictationProvider = .parakeet

        let persistedValue = defaults.string(forKey: UserDefaultsKeys.App.activeDictationProvider)
        #expect(persistedValue == AppSettingsStore.ActiveDictationProvider.parakeet.rawValue)
    }

    @Test func liveActivitiesEnabledDefaultsToTrue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.liveActivitiesEnabled)
    }

    @Test func liveActivitiesEnabledWritesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AppSettingsStore(defaults: defaults)

        store.liveActivitiesEnabled = false

        let persistedValue = defaults.object(forKey: UserDefaultsKeys.liveActivitiesEnabled) as? Bool
        #expect(persistedValue == false)
    }

    @Test func liveActivitiesEnabledRestoresPersistedFalseValue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: UserDefaultsKeys.liveActivitiesEnabled)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.liveActivitiesEnabled == false)
    }

    @Test func aiStyleTransformStyleDefaultsToNone() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.aiStyleTransformStyle == .none)
    }

    @Test func aiStyleTransformStyleWritesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AppSettingsStore(defaults: defaults)

        store.aiStyleTransformStyle = .chill

        let persistedValue = defaults.string(forKey: UserDefaultsKeys.aiStyleTransformStyle)
        #expect(persistedValue == StyleRewriteStyle.chill.rawValue)
    }

    @Test func aiStyleTransformStyleRestoresPersistedValue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(StyleRewriteStyle.polished.rawValue, forKey: UserDefaultsKeys.aiStyleTransformStyle)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.aiStyleTransformStyle == .polished)
    }

    @Test func aiStyleTransformStyleMigratesEnabledBooleanToPolished() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: UserDefaultsKeys.aiStyleTransformEnabled)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.aiStyleTransformStyle == .polished)
    }

    @Test func aiStyleTransformStyleMigratesDisabledBooleanToNone() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: UserDefaultsKeys.aiStyleTransformEnabled)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.aiStyleTransformStyle == .none)
    }
}
