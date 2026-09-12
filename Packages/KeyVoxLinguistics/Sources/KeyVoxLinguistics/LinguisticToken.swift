import Foundation

public struct LinguisticToken: Sendable {
    public enum Identity: Sendable { case ordinaryWord, name, unknown }
    public enum Inflection: Sendable { case singular, plural, unknown }

    /// UTF-16 coordinates into the original, unmodified input.
    public let range: NSRange
    public let role: LexicalRole?
    public let lemma: String?
    public let identity: Identity
    public let inflection: Inflection

    public init(
        range: NSRange,
        role: LexicalRole? = nil,
        lemma: String? = nil,
        identity: Identity = .unknown,
        inflection: Inflection = .unknown
    ) {
        self.range = range
        self.role = role
        self.lemma = lemma
        self.identity = identity
        self.inflection = inflection
    }
}
