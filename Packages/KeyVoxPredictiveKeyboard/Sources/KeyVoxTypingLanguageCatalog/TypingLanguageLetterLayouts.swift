import Foundation

/// One typing language's letter layouts, read from its `language.json`: the layout the keyboard
/// shows unless the user picks another, and the others Apple's keyboard offers for the language.
public struct TypingLanguageLetterLayouts: Decodable, Equatable, Sendable {
    /// The language's folder name in `PredictiveData`, such as `en`.
    public let identifier: String
    /// The layout the keyboard shows unless the user picks another, by Apple's name.
    public let defaultLetterLayout: String
    /// The other layouts Apple's keyboard offers for the language, in Apple's order.
    public let alternativeLetterLayouts: [String]

    /// Every layout the language offers, in Apple's order: the default first.
    public var letterLayouts: [String] {
        [defaultLetterLayout] + alternativeLetterLayouts
    }

    public init(identifier: String, defaultLetterLayout: String, alternativeLetterLayouts: [String]) {
        self.identifier = identifier
        self.defaultLetterLayout = defaultLetterLayout
        self.alternativeLetterLayouts = alternativeLetterLayouts
    }
}
