enum StandardEvaluationPolicy {
    static let minimumSingleTokenLength = 3

    static let pluralHomophonePhoneticMinimum = 0.95
    static let pluralHomophoneTextMinimum = 0.35
    static let pluralHomophoneBonus = 0.14

    static let singleTokenPossessiveMinimumThreshold = 0.82
    static let singleTokenPossessiveThresholdDelta = 0.08
    static let singleTokenPluralPhoneticMinimum = 0.92
    static let singleTokenPluralMinimumThreshold = 0.78
    static let singleTokenPluralThresholdDelta = 0.12

    static let peerSupportSimilarityMaximum = 0.70
    static let stylizedSurfaceSimilarityMinimum = 0.82
    static let titlecaseKnownWordSurfaceMinimum = 0.90
    static let stylizedStrongTextThreshold = 0.50
    static let stylizedStrongFallbackThreshold = 0.60
    static let stylizedModerateFallbackThreshold = 0.55
    static let stylizedStrongSurfaceThreshold = 0.72
    static let properNounSimilarityMinimum = 0.80
    static let properNounBlendedSimilarityMinimum = 0.74
    static let properNounThreshold = 0.78

    static let twoTokenStrongEvidenceThreshold = 0.72
    static let twoTokenExactTailStylizedThreshold = stylizedModerateFallbackThreshold
    static let twoTokenModerateEvidenceThreshold = 0.55

    static let commonWordStylizedBypassMinimum = 0.82
    static let commonWordFallbackBypassMinimum = 0.58
    static let commonWordStructuralBypassMinimum = 0.60
    static let commonWordStructuralContextThreshold = 0.60
    static let commonWordAttributionContextThreshold = 0.62
    static let structuralLeftContextMaximumLength = 4
    static let structuralRightContextMinimumLength = 7
}
