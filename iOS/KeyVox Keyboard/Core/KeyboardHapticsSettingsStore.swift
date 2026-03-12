import Foundation

struct KeyboardHapticsSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    var isKeypressHapticsEnabled: Bool {
        defaults.object(forKey: iOSUserDefaultsKeys.keyboardHapticsEnabled) as? Bool ?? true
    }
}
