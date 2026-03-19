import Foundation

struct KeyboardHapticsSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    var isKeypressHapticsEnabled: Bool {
        defaults.object(forKey: UserDefaultsKeys.keyboardHapticsEnabled) as? Bool ?? true
    }
}
