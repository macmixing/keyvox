import Foundation

struct KeyboardCapsLockStateStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        defaults.object(forKey: UserDefaultsKeys.capsLockEnabled) as? Bool ?? false
    }

    func setEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: UserDefaultsKeys.capsLockEnabled)
    }

    @discardableResult
    func toggle() -> Bool {
        let updated = !isEnabled
        setEnabled(updated)
        return updated
    }
}
