import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

struct PlatformLinguisticAnalyzer: LinguisticAnalyzing {
    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        #if canImport(NaturalLanguage)
        return AppleLinguisticAnalyzer().analyze(
            text, range: range, languageCode: languageCode, features: features, grouping: grouping
        )
        #else
        return UnicodeLinguisticAnalyzer().analyze(
            text, range: range, languageCode: languageCode, features: features, grouping: grouping
        )
        #endif
    }
}
