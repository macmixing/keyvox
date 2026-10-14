import Foundation
import KeyVoxEmoji

/// The bundled emoji search, read once off the main thread the first time the search opens and
/// kept while the keyboard runs. Use from the main thread.
final class KeyboardEmojiSearchIndex {
    static let shared = KeyboardEmojiSearchIndex()

    private var search: EmojiSearch?
    private var waiting: [() -> Void] = []
    private var isLoading = false

    /// Calls `completion` on the main thread once the search is read, at once when it already is.
    func load(_ completion: @escaping () -> Void) {
        if search != nil {
            completion()
            return
        }
        waiting.append(completion)
        guard isLoading == false else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let search = try? EmojiSearch.bundled()
            DispatchQueue.main.async { [self] in
                self.search = search
                isLoading = false
                let waiting = self.waiting
                self.waiting = []
                waiting.forEach { $0() }
            }
        }
    }

    /// The emoji `text` finds, in order, once read; none before.
    func results(for text: String) -> [String] {
        search?.results(for: text) ?? []
    }
}
