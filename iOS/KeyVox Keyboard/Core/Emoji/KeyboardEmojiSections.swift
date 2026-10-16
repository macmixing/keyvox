import Foundation
import KeyVoxEmoji

/// The emoji page's sections on this phone: the bundled catalog's emoji the system draws
/// (`KeyboardEmojiSupport`), worked out once off the main thread and kept while the keyboard runs,
/// after the emoji the user used most. Use from the main thread.
final class KeyboardEmojiSections {
    static let shared = KeyboardEmojiSections()

    private struct Loaded {
        let catalog: [EmojiKeyboardSection]
        /// What fills the Frequently Used section after the used emoji: the starters, then the
        /// catalog's emoji in order, so a section of any size fills.
        let fill: [String]
        let emojiByText: [String: Emoji]
    }

    private var loaded: Loaded?
    private var waiting: [() -> Void] = []
    private var isLoading = false

    /// Calls `completion` on the main thread once the catalog is worked out, at once when it
    /// already is.
    func load(_ completion: @escaping () -> Void) {
        if loaded != nil {
            completion()
            return
        }
        waiting.append(completion)
        guard isLoading == false else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let catalog = (try? EmojiCatalog.bundled())?.keyboardSections(isDrawable: KeyboardEmojiSupport.canDraw) ?? []
            let starters = ((try? EmojiFrequentlyUsed.bundledStarters()) ?? []).filter(KeyboardEmojiSupport.canDraw)
            let emojiByText = Dictionary(
                catalog.flatMap(\.emoji).map { ($0.text, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            var seen = Set<String>()
            let fill = (starters + catalog.flatMap(\.emoji).map(\.text)).filter { seen.insert($0).inserted }
            DispatchQueue.main.async { [self] in
                loaded = Loaded(catalog: catalog, fill: fill, emojiByText: emojiByText)
                isLoading = false
                let waiting = self.waiting
                self.waiting = []
                waiting.forEach { $0() }
            }
        }
    }

    /// The catalog's sections, which follow Frequently Used on the page, once loaded.
    var catalog: [EmojiKeyboardSection] {
        loaded?.catalog ?? []
    }

    /// The emoji a Frequently Used section of `count` emoji shows for `frequentlyUsed`, once loaded.
    func frequentlyUsedEmoji(_ frequentlyUsed: EmojiFrequentlyUsed, count: Int) -> [Emoji] {
        guard let loaded else { return [] }
        return frequentlyUsed.shown(starters: loaded.fill, count: count).filter(KeyboardEmojiSupport.canDraw).map { text in
            loaded.emojiByText[text] ?? Emoji(text: text, name: text, skinToneVariants: [])
        }
    }

    /// The catalog's emoji typed as `text`, once loaded, when the system draws it.
    func emoji(_ text: String) -> Emoji? {
        loaded?.emojiByText[text]
    }
}
