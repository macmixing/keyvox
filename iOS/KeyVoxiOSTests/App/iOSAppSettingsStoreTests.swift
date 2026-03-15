import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSAppSettingsStoreTests {
    @Test func liveActivitiesEnabledDefaultsToTrue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = iOSAppSettingsStore(defaults: defaults)

        #expect(store.liveActivitiesEnabled)
    }

    @Test func liveActivitiesEnabledWritesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = iOSAppSettingsStore(defaults: defaults)

        store.liveActivitiesEnabled = false

        let persistedValue = defaults.object(forKey: iOSUserDefaultsKeys.liveActivitiesEnabled) as? Bool
        #expect(persistedValue == false)
    }

    @Test func liveActivitiesEnabledRestoresPersistedFalseValue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: iOSUserDefaultsKeys.liveActivitiesEnabled)

        let store = iOSAppSettingsStore(defaults: defaults)

        #expect(store.liveActivitiesEnabled == false)
    }
}
