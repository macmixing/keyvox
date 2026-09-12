#if canImport(NaturalLanguage)
import NaturalLanguage

enum AppleLinguisticCapabilities {
    static func supported(_ requested: LinguisticFeatures, language: NLLanguage?) -> LinguisticFeatures {
        var available: LinguisticFeatures = [.wordBoundaries]
        guard let language else { return available }
        let schemes = NLTagger.availableTagSchemes(for: .word, language: language)
        if requested.contains(.roles), schemes.contains(.lexicalClass) { available.insert(.roles) }
        if requested.contains(.lemmas), schemes.contains(.lemma) { available.insert(.lemmas) }
        if requested.contains(.names), schemes.contains(.nameType) { available.insert(.names) }
        return available
    }
}
#endif
