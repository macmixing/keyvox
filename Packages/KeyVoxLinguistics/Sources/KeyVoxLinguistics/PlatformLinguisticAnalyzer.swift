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
        // Explicitly unavailable until a host supplies a verified portable model.
        // No grammatical roles, lemmas or names are inferred from surface spelling.
        return LinguisticAnalysis(tokens: [], availableFeatures: [])
        #endif
    }
}
