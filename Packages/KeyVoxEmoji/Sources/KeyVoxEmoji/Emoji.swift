/// One emoji a keyboard offers, with the skin-tone versions it comes in.
public struct Emoji: Sendable, Equatable {
    public let text: String
    /// Unicode's name for the emoji, such as "waving hand".
    public let name: String
    /// The emoji in each skin tone, in Unicode's order: five for one person, twenty-five when
    /// two people each take a tone; empty when it comes in none.
    public let skinToneVariants: [String]

    public init(text: String, name: String, skinToneVariants: [String]) {
        self.text = text
        self.name = name
        self.skinToneVariants = skinToneVariants
    }
}
