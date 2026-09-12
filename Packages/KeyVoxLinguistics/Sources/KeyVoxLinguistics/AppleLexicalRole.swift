#if canImport(NaturalLanguage)
import NaturalLanguage

extension LexicalRole {
    init?(_ tag: NLTag?) {
        switch tag {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        case .pronoun: self = .pronoun
        case .determiner: self = .determiner
        case .particle: self = .particle
        case .preposition: self = .preposition
        case .number: self = .number
        case .conjunction: self = .conjunction
        case .interjection: self = .interjection
        case .classifier: self = .classifier
        case .idiom: self = .idiom
        case .otherWord: self = .otherWord
        default:
            guard tag?.rawValue == "Ordinal" else { return nil }
            self = .ordinal
        }
    }
}
#endif
