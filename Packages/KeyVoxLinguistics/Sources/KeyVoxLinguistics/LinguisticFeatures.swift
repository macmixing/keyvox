public struct LinguisticFeatures: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let roles = Self(rawValue: 1 << 0)
    public static let lemmas = Self(rawValue: 1 << 1)
    public static let names = Self(rawValue: 1 << 2)
    public static let wordBoundaries = Self(rawValue: 1 << 3)
}

public enum LinguisticGrouping: Sendable {
    case words
    case namedPhrases
}
