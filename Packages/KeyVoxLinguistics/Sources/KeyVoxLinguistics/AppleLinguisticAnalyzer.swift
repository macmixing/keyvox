#if canImport(NaturalLanguage)
import Foundation
import NaturalLanguage

struct AppleLinguisticAnalyzer: LinguisticAnalyzing {
    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let stringRange = Range(range ?? fullRange, in: text) else {
            return LinguisticAnalysis(tokens: [], availableFeatures: [])
        }
        if grouping == .namedPhrases {
            return namedPhrases(in: text, range: NSRange(stringRange, in: text))
        }

        var schemes: [NLTagScheme] = []
        if features.contains(.roles) { schemes.append(.lexicalClass) }
        if features.contains(.lemmas) { schemes.append(.lemma) }
        if features.contains(.names) { schemes.append(.nameType) }
        let tagger = NLTagger(tagSchemes: schemes)
        tagger.string = text
        var resolvedLanguage: NLLanguage?
        if let languageCode {
            let code = languageCode.replacingOccurrences(of: "_", with: "-")
            if !code.isEmpty {
                resolvedLanguage = NLLanguage(rawValue: code)
                tagger.setLanguage(resolvedLanguage!, range: text.startIndex..<text.endIndex)
            }
        }

        func token(_ range: Range<String.Index>) -> LinguisticToken {
            let role = features.contains(.roles)
                ? LexicalRole(tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0) : nil
            let lemma = features.contains(.lemmas)
                ? tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue : nil
            let name = features.contains(.names)
                ? tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType).0 : nil
            let identity: LinguisticToken.Identity
            switch name {
            case .otherWord: identity = .ordinaryWord
            case .personalName, .placeName, .organizationName: identity = .name
            default: identity = .unknown
            }
            let inflection: LinguisticToken.Inflection
            if role == .noun, let lemma {
                let tokenText = String(text[range])
                inflection = tokenText.compare(
                    lemma,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame ? .singular : .plural
            } else {
                inflection = .unknown
            }
            return LinguisticToken(
                range: NSRange(range, in: text),
                role: role,
                lemma: lemma,
                identity: identity,
                inflection: inflection
            )
        }

        var tokens: [LinguisticToken] = []
        if features.contains(.wordBoundaries) {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = text
            tokenizer.enumerateTokens(in: stringRange) { range, _ in
                tokens.append(token(range))
                return true
            }
        } else {
            let scheme: NLTagScheme = features.contains(.names) && !features.contains(.roles) ? .nameType : .lexicalClass
            tagger.enumerateTags(in: stringRange, unit: .word, scheme: scheme, options: [.omitWhitespace, .omitPunctuation]) { _, range in
                tokens.append(token(range))
                return true
            }
        }
        return LinguisticAnalysis(
            tokens: tokens,
            availableFeatures: AppleLinguisticCapabilities.supported(features, language: resolvedLanguage ?? tagger.dominantLanguage)
        )
    }

    private func namedPhrases(in text: String, range: NSRange) -> LinguisticAnalysis {
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        tagger.string = text
        var tokens: [LinguisticToken] = []
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range, _ in
            tokens.append(LinguisticToken(range: range, role: LexicalRole(tag.map { NLTag(rawValue: $0.rawValue) })))
        }
        return LinguisticAnalysis(
            tokens: tokens,
            availableFeatures: AppleLinguisticCapabilities.supported(.roles, language: tagger.dominantLanguage.map(NLLanguage.init(rawValue:)))
        )
    }
}
#endif
