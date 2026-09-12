import Foundation

/// Optional lexical evidence loaded from an unmodified Princeton WordNet index.
/// Asset installation and ownership remain the host's responsibility.
struct WordNetLexicalDatabase: Sendable {
    enum Failure: Error { case missingIndex(String) }

    private let nouns: Set<String>
    private let verbs: Set<String>
    private let adjectives: Set<String>
    private let adverbs: Set<String>

    init(directory: URL) throws {
        nouns = try Self.loadIndex(named: "index.noun", from: directory)
        verbs = try Self.loadIndex(named: "index.verb", from: directory)
        adjectives = try Self.loadIndex(named: "index.adj", from: directory)
        adverbs = try Self.loadIndex(named: "index.adv", from: directory)
    }

    func roles(for word: String) -> [LexicalRole] {
        let normalized = word.lowercased()
        var roles: [LexicalRole] = []
        if nouns.contains(normalized) { roles.append(.noun) }
        if verbs.contains(normalized) { roles.append(.verb) }
        if adjectives.contains(normalized) { roles.append(.adjective) }
        if adverbs.contains(normalized) { roles.append(.adverb) }
        return roles
    }

    private static func loadIndex(named name: String, from directory: URL) throws -> Set<String> {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            throw Failure.missingIndex(name)
        }
        return Set(contents.split(separator: "\n").compactMap { line -> String? in
            guard let first = line.first, !first.isWhitespace else { return nil }
            guard let lemma = line.split(separator: " ", maxSplits: 1).first,
                  !lemma.contains("_") else { return nil }
            return String(lemma)
        })
    }
}
