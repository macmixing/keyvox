import Foundation
import KeyVoxEmoji

/// The emoji the user used, kept in the app group so the Frequently Used section keeps them when
/// the keyboard starts again. Use from the main thread.
final class KeyboardEmojiFrequentlyUsedStore {
    private let defaults: UserDefaults?
    private(set) var frequentlyUsed: EmojiFrequentlyUsed

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)) {
        self.defaults = defaults
        frequentlyUsed = defaults?.data(forKey: UserDefaultsKeys.emojiFrequentlyUsed)
            .flatMap { try? JSONDecoder().decode(EmojiFrequentlyUsed.self, from: $0) }
            ?? EmojiFrequentlyUsed()
    }

    func recordUse(of emoji: String) {
        frequentlyUsed.recordUse(of: emoji)
        defaults?.set(try? JSONEncoder().encode(frequentlyUsed), forKey: UserDefaultsKeys.emojiFrequentlyUsed)
    }
}
