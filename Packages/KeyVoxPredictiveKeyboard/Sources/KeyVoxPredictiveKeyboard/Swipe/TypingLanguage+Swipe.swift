import Foundation

extension TypingLanguage {
    /// Whether the language bundles a swipe model, so a finger sliding across its letter keys can
    /// type a word: its `swipe.json`, the model's encoder, and the swipe lexicon built for it. A
    /// language without one is typed by tapping alone, and decodes no swipe.
    public var offersSwipeTyping: Bool {
        [SwipeModelSettings.fileName, SwipeEncoderNetwork.fileName, SwipeLexiconFormat.fileName]
            .allSatisfy { resources.optionalDataURL($0) != nil }
    }
}
