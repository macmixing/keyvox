import Foundation

public struct LinguisticToken: Sendable {
    public enum Identity: Sendable { case ordinaryWord, name, unknown }

    /// UTF-16 coordinates into the original, unmodified input.
    public let range: NSRange
    public let role: LexicalRole?
    public let lemma: String?
    public let identity: Identity

    public init(range: NSRange, role: LexicalRole? = nil, lemma: String? = nil, identity: Identity = .unknown) {
        self.range = range
        self.role = role
        self.lemma = lemma
        self.identity = identity
    }
}
