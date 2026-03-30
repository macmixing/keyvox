import Foundation
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
}
