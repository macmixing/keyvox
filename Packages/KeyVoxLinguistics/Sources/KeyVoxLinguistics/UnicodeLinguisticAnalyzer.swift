import Foundation

/// Word segmentation without claims of grammatical or named-entity analysis.
public struct UnicodeLinguisticAnalyzer: LinguisticAnalyzing {
    public init() {}

    public func analyze(_ text: String, range: NSRange?, languageCode: String?,
                        features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
        let tokens = UnicodeWordTokenizer.tokens(in: text).filter { token in
            token.isWord && (range.map { NSIntersectionRange($0, token.range).length > 0 } ?? true)
        }.map { LinguisticToken(range: $0.range) }
        return LinguisticAnalysis(tokens: tokens, availableFeatures: features.intersection(.wordBoundaries))
    }
}
