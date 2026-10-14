import Foundation

/// The skin tone the user last chose for each emoji, kept in the app group: the emoji page shows
/// and types that emoji in that tone from then on, as the system emoji keyboard does. Use from the
/// main thread.
final class KeyboardEmojiSkinToneStore {
    private let defaults: UserDefaults?
    /// Each emoji as it comes, by the skin-tone version last chosen for it.
    private(set) var chosenTones: [String: String]

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)) {
        self.defaults = defaults
        chosenTones = defaults?.dictionary(forKey: UserDefaultsKeys.emojiSkinTones) as? [String: String] ?? [:]
    }

    /// Remembers `version` for `emoji`; choosing the emoji as it comes forgets the tone.
    func choose(_ version: String, for emoji: String) {
        chosenTones[emoji] = version == emoji ? nil : version
        defaults?.set(chosenTones, forKey: UserDefaultsKeys.emojiSkinTones)
    }
}
