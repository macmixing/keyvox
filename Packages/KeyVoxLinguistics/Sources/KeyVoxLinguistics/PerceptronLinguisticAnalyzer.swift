import Foundation

/// Optional host-selected grammatical model. Neither model assets nor a default
/// language are imposed on applications using KeyVoxLinguistics.
public struct PerceptronLinguisticAnalyzer: LinguisticAnalyzing {
    private let model: PerceptronModel
    private let languages: Set<String>
    private let languageCode: String?

    public init(modelDirectory: URL, languageCode: String?) throws {
        let (descriptor, model) = try PerceptronModelLoader.load(directory: modelDirectory)
        self.model = model
        languages = Set(descriptor.languages.compactMap(ModelLanguageIdentifier.base))
        self.languageCode = languageCode
    }

    public func analyze(_ text: String, range: NSRange?, languageCode: String?,
                        features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
        guard let language = languageCode ?? self.languageCode,
              let base = ModelLanguageIdentifier.base(language),
              languages.contains(base), features.contains(.roles) else {
            return UnicodeLinguisticAnalyzer().analyze(text, range: range, languageCode: languageCode,
                                                       features: features, grouping: grouping)
        }
        let words = UnicodeWordTokenizer.tokens(in: text)
        guard let tags = model.tags(for: words.map(\.text)) else {
            return UnicodeLinguisticAnalyzer().analyze(text, range: range, languageCode: languageCode,
                                                       features: features, grouping: grouping)
        }
        let tokens = zip(words, tags).compactMap { token, tag -> LinguisticToken? in
            guard token.isWord, range.map({ NSIntersectionRange($0, token.range).length > 0 }) ?? true else { return nil }
            return LinguisticToken(range: token.range, role: PennLexicalRole.role(for: tag))
        }
        return LinguisticAnalysis(tokens: tokens, availableFeatures: features.intersection([.roles, .wordBoundaries]))
    }
}
