enum PennContextualRoleResolver {
    static func role(for tag: String, at index: Int, tags: [String]) -> LexicalRole? {
        if tag == "VBG", index == 0, tags.element(at: 1)?.hasPrefix("NN") == true {
            return .noun
        }
        if let direct = PennLexicalRole.role(for: tag) { return direct }
        switch tag {
        case "TO":
            return tags.element(at: index + 1)?.hasPrefix("VB") == true ? .particle : .preposition
        case "IN":
            let next = tags.element(at: index + 1)
            let secondNext = tags.element(at: index + 2)
            let introducesClause = ["PRP", "WP", "EX"].contains(next)
                && secondNext?.hasPrefix("VB") == true
            return introducesClause ? .conjunction : .preposition
        default:
            return nil
        }
    }
}

private extension Array {
    func element(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
