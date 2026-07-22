public struct DictationDeterministicState: Hashable, Sendable {
    public let paragraphsEnabled: Bool
    public let listsEnabled: Bool

    public init(paragraphsEnabled: Bool, listsEnabled: Bool) {
        self.paragraphsEnabled = paragraphsEnabled
        self.listsEnabled = listsEnabled
    }

    public var debugDescription: String {
        "paragraphs=\(paragraphsEnabled),lists=\(listsEnabled)"
    }
}
