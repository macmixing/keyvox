enum WordNetLexicalRoleResolver {
    static func role(
        for word: String,
        predictedTag: String,
        at index: Int,
        tags: [String],
        allowsLexicalOverride: Bool,
        database: WordNetLexicalDatabase?
    ) -> LexicalRole? {
        let predictedRole = PennContextualRoleResolver.role(for: predictedTag, at: index, tags: tags)
        guard allowsLexicalOverride, let database else { return predictedRole }
        let lexicalRoles = database.roles(for: word)

        if predictedRole == .verb, lexicalRoles == [.noun] {
            return .noun
        }

        if predictedRole == .conjunction,
           lexicalRoles.contains(.adverb),
           index > 0,
           PennLexicalRole.role(for: tags[index - 1]) == .verb,
           index + 1 < tags.count,
           PennLexicalRole.role(for: tags[index + 1]) == .pronoun {
            return .particle
        }

        return predictedRole
    }
}
