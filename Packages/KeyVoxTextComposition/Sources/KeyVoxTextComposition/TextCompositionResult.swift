public struct TextCompositionResult: Equatable, Sendable {
    public let text: String
    public let shouldDeleteFollowingCodePoint: Bool

    public init(text: String, shouldDeleteFollowingCodePoint: Bool) {
        self.text = text
        self.shouldDeleteFollowingCodePoint = shouldDeleteFollowingCodePoint
    }
}
