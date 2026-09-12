/// Maps the model's standardized Penn Treebank labels to consumed semantic roles.
/// Proper-noun tags do not claim named-entity recognition or lemma support.
enum PennLexicalRole {
    static func role(for tag: String) -> LexicalRole? {
        switch tag {
        case "NN", "NNS", "NNP", "NNPS": return .noun
        case "VB", "VBD", "VBG", "VBN", "VBP", "VBZ", "MD": return .verb
        case "JJ", "JJR", "JJS": return .adjective
        case "RB", "RBR", "RBS", "WRB": return .adverb
        case "PRP", "WP", "WP$", "EX": return .pronoun
        case "DT", "PDT", "WDT", "PRP$": return .determiner
        case "RP", "POS": return .particle
        // These labels require sentence context to distinguish their roles.
        case "IN", "TO": return nil
        case "CD": return .number
        case "CC": return .conjunction
        case "UH": return .interjection
        case "FW": return .otherWord
        default: return nil
        }
    }

    static func inflection(for tag: String) -> LinguisticToken.Inflection {
        switch tag {
        case "NN", "NNP": return .singular
        case "NNS", "NNPS": return .plural
        default: return .unknown
        }
    }
}
