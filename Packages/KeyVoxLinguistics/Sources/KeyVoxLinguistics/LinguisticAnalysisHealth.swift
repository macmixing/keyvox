import Foundation

enum LinguisticAnalysisHealth {
    enum Result {
        case healthy
        case inconclusive
        case unhealthy(Reason)
    }

    enum Reason: String {
        case invalidTokenRange = "invalid-token-range"
        case missingWordBoundaries = "missing-word-boundaries"
        case unavailableRequestedFeatures = "unavailable-requested-features"
        case missingRoleEvidence = "missing-role-evidence"
        case missingLemmaEvidence = "missing-lemma-evidence"
    }

    static func evaluate(
        text: String,
        requestedFeatures: LinguisticFeatures,
        analysis: LinguisticAnalysis
    ) -> Result {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard analysis.tokens.allSatisfy({ token in
            token.range.location >= fullRange.location
                && token.range.length > 0
                && NSMaxRange(token.range) <= NSMaxRange(fullRange)
        }) else {
            return .unhealthy(.invalidTokenRange)
        }

        let hasLexicalInput = text.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
        guard hasLexicalInput else { return .inconclusive }

        if requestedFeatures.contains(.wordBoundaries), analysis.tokens.isEmpty {
            return .unhealthy(.missingWordBoundaries)
        }
        guard !analysis.tokens.isEmpty else { return .inconclusive }

        let semanticFeatures = requestedFeatures.intersection([.roles, .lemmas, .names])
        guard !semanticFeatures.isEmpty else { return .healthy }
        guard analysis.availableFeatures.isSuperset(of: semanticFeatures) else {
            return .unhealthy(.unavailableRequestedFeatures)
        }

        if semanticFeatures.contains(.roles),
           !analysis.tokens.contains(where: { token in
               guard let role = token.role else { return false }
               if case .otherWord = role { return false }
               return true
           }) {
            return .unhealthy(.missingRoleEvidence)
        }
        if semanticFeatures.contains(.lemmas),
           !analysis.tokens.contains(where: { token in
               token.lemma?.isEmpty == false
           }) {
            return .unhealthy(.missingLemmaEvidence)
        }
        return .healthy
    }
}
