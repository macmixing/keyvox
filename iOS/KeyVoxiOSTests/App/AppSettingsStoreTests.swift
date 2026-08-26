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

    @Test func compactKeysEnabledDefaultsToTrue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.compactKeysEnabled)
    }

    @Test func disablingCompactKeysPersistsAvailabilityAndClearsActiveMode() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: UserDefaultsKeys.compactKeysActive)
        let store = AppSettingsStore(defaults: defaults)

        store.compactKeysEnabled = false

        #expect(defaults.object(forKey: UserDefaultsKeys.compactKeysEnabled) as? Bool == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.compactKeysActive) as? Bool == false)
    }

    @Test func compactKeysEnabledRestoresPersistedFalseValueAndClearsActiveMode() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: UserDefaultsKeys.compactKeysEnabled)
        defaults.set(true, forKey: UserDefaultsKeys.compactKeysActive)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.compactKeysEnabled == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.compactKeysActive) as? Bool == false)
    }

    @Test func selectedVibeDefaultsToNone() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.selectedVibe == .none)
    }

    @Test func selectedVibeWritesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AppSettingsStore(defaults: defaults)

        store.selectedVibe = .chill

        let persistedValue = defaults.string(forKey: UserDefaultsKeys.selectedVibe)
        #expect(persistedValue == StyleRewriteStyle.chill.rawValue)
    }

    @Test func selectedVibeRestoresPersistedValue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(StyleRewriteStyle.polished.rawValue, forKey: UserDefaultsKeys.selectedVibe)

        let store = AppSettingsStore(defaults: defaults)

        #expect(store.selectedVibe == .polished)
    }

    @Test func selectedVibeResolvesNoneWhenVibesAccessIsUnavailable() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(StyleRewriteStyle.chill.rawValue, forKey: UserDefaultsKeys.selectedVibe)

        let style = AppSettingsStore.resolvedSelectedVibe(
            from: defaults,
            canUseVibes: false
        )

        #expect(style == .none)
    }

    @Test func selectedVibeRestoresNoneWhenVibesAccessIsUnavailable() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(StyleRewriteStyle.chill.rawValue, forKey: UserDefaultsKeys.selectedVibe)

        let store = AppSettingsStore(
            defaults: defaults,
            canUseVibesProvider: { false }
        )

        #expect(store.selectedVibe == .none)
        #expect(defaults.string(forKey: UserDefaultsKeys.selectedVibe) == StyleRewriteStyle.none.rawValue)
    }
}
