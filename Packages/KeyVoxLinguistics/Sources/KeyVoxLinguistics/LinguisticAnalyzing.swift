import Foundation

public protocol LinguisticAnalyzing: Sendable {
    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis
}

public enum TextLinguistics {
    /// Scoped overrides let hosts select a language/model without global mutable state.
    @TaskLocal public static var provider: any LinguisticAnalyzing = PlatformLinguisticAnalyzer()
    @TaskLocal public static var processingLanguageCode: String?

    public static func analyze(
        _ text: String,
        range: NSRange? = nil,
        languageCode: String? = nil,
        features: LinguisticFeatures = [.roles],
        grouping: LinguisticGrouping = .words
    ) -> LinguisticAnalysis {
        provider.analyze(
            text,
            range: range,
            languageCode: languageCode ?? processingLanguageCode,
            features: features,
            grouping: grouping
        )
    }
}
