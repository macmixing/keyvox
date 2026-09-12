import Foundation

/// Optional host-selected grammatical model. Neither model assets nor a default
/// language are imposed on applications using KeyVoxLinguistics.
public struct PerceptronLinguisticAnalyzer: LinguisticAnalyzing {
    private let model: PerceptronModel
    private let lexicalDatabase: WordNetLexicalDatabase?
    private let languages: Set<String>
    private let languageCode: String?

    public init(modelDirectory: URL, lexicalDatabaseDirectory: URL? = nil, languageCode: String?) throws {
        let (descriptor, model) = try PerceptronModelLoader.load(directory: modelDirectory)
        self.model = model
        lexicalDatabase = try lexicalDatabaseDirectory.map(WordNetLexicalDatabase.init(directory:))
        languages = Set(descriptor.languages.compactMap(ModelLanguageIdentifier.base))
        self.languageCode = languageCode
    }

    public func analyze(_ text: String, range: NSRange?, languageCode: String?,
                        features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
        guard let language = languageCode ?? self.languageCode,
              let base = ModelLanguageIdentifier.base(language),
              languages.contains(base),
              !features.intersection([.roles, .names]).isEmpty else {
            return UnicodeLinguisticAnalyzer().analyze(text, range: range, languageCode: languageCode,
                                                       features: features, grouping: grouping)
        }
        let words = UnicodeWordTokenizer.tokens(in: text)
        guard let tags = model.tags(for: words.map(\.text)) else {
            return UnicodeLinguisticAnalyzer().analyze(text, range: range, languageCode: languageCode,
                                                       features: features, grouping: grouping)
        }
        let tokens = zip(words.indices, zip(words, tags)).compactMap { index, pair -> LinguisticToken? in
            let (token, tag) = pair
            guard token.isWord, range.map({ NSIntersectionRange($0, token.range).length > 0 }) ?? true else { return nil }
            let identity = features.contains(.names)
                ? identity(for: token.text, tag: tag, index: index, tags: tags)
                : .unknown
            let role = features.contains(.roles)
                ? WordNetLexicalRoleResolver.role(
                    for: token.text,
                    predictedTag: tag,
                    at: index,
                    tags: tags,
                    allowsLexicalOverride: model.knownTag(for: token.text) == nil,
                    database: lexicalDatabase
                )
                : nil
            return LinguisticToken(
                range: token.range,
                role: role,
                identity: identity,
                inflection: features.contains(.roles) ? PennLexicalRole.inflection(for: tag) : .unknown
            )
        }
        var available: LinguisticFeatures = [.roles, .wordBoundaries]
        if features.contains(.names) { available.insert(.names) }
        return LinguisticAnalysis(tokens: tokens, availableFeatures: features.intersection(available))
    }

    private func identity(for word: String, tag: String, index: Int, tags: [String]) -> LinguisticToken.Identity {
        let lowercaseTag = model.knownTag(for: word.lowercased())
        let isPredictedProperNoun = tag == "NNP" || tag == "NNPS"
        let isCapitalizedKnownNoun = word.first?.isUppercase == true
            && lowercaseTag?.hasPrefix("NN") == true
        guard isPredictedProperNoun || isCapitalizedKnownNoun else { return .ordinaryWord }

        if let lowercaseTag,
           lowercaseTag.hasPrefix("VB") || lowercaseTag == "IN" || lowercaseTag == "TO" {
            return .ordinaryWord
        }
        if lowercaseTag == "NN" || lowercaseTag == "NNS" {
            let previous = index > 0 ? tags[index - 1] : nil
            let next = index + 1 < tags.count ? tags[index + 1] : nil
            if (previous == "IN" || previous == "CC") && next?.hasPrefix("VB") == true {
                return .ordinaryWord
            }
        }
        return .name
    }
}
