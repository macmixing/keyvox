import Foundation
import KeyVoxLinguistics

/// Structural, offline date and address recognition for platforms without
/// `NSDataDetector`. It deliberately uses locale metadata and Unicode
/// properties rather than a product vocabulary.
struct PortableNumericTextProtection: NumericTextProtectionAnalyzing {
    private static let numericDate = expression(
        #"\b(?:\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b"#
    )
    private static let titledAddress = expression(
        #"\b\d{1,6}\h+(?:(?:\p{Lu}[\p{L}\p{M}'’-]*\h+){2,}\p{Lu}[\p{L}\p{M}'’-]*|\p{Lu}[\p{L}\p{M}'’-]*\h+\p{Lu}[\p{L}\p{M}'’-]*(?=\h*(?:$|\p{P}|\R)))\b"#
    )
    private static let monthDate: NSRegularExpression? = {
        let identifiers = Set([Locale.current.identifier, "en_US_POSIX"])
        let names = identifiers.flatMap { identifier -> [String] in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            formatter.calendar = Calendar(identifier: .gregorian)
            return [
                formatter.keyVoxMonthSymbols,
                formatter.keyVoxStandaloneMonthSymbols,
                formatter.keyVoxShortMonthSymbols,
                formatter.keyVoxShortStandaloneMonthSymbols,
            ].flatMap { $0 }
        }
        let alternatives = Set(names)
            .filter { !$0.isEmpty }
            .map(NSRegularExpression.escapedPattern(for:))
            .sorted { $0.count > $1.count }
            .joined(separator: "|")
        guard !alternatives.isEmpty else { return nil }
        return expression(#"\b(?:"# + alternatives + #")\.?\s+\d{1,2}(?:,\s*|\s+)\d{4}\b|\b(?:"#
            + alternatives + #")\.?\s+\d{4}\b"#, options: [.caseInsensitive])
    }()

    func analyze(_ text: String) -> NumericTextProtection {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let dateRanges = [Self.numericDate, Self.monthDate]
            .compactMap { $0 }
            .flatMap { $0.matches(in: text, range: fullRange).map(\.range) }
        let addressRanges = addressRanges(in: text, fullRange: fullRange)
        return NumericTextProtection(
            ranges: dateRanges + addressRanges,
            availableCategories: Set(NumericTextProtection.Category.allCases)
        )
    }

    private func addressRanges(in text: String, fullRange: NSRange) -> [NSRange] {
        guard let matches = Self.titledAddress?.matches(in: text, range: fullRange),
              !matches.isEmpty else {
            return []
        }
        let analysis = TextLinguistics.analyze(
            text,
            range: fullRange,
            features: [.roles],
            grouping: .words
        )
        guard analysis.availableFeatures.contains(.roles) else {
            return matches.map(\.range)
        }

        return matches.compactMap { match in
            isSemanticallyPlausibleAddress(match.range, in: text, tokens: analysis.tokens)
                ? match.range
                : nil
        }
    }

    private func isSemanticallyPlausibleAddress(
        _ range: NSRange,
        in text: String,
        tokens: [LinguisticToken]
    ) -> Bool {
        if let followingToken = tokens.first(where: { $0.range.location >= NSMaxRange(range) }) {
            let separatorRange = NSRange(
                location: NSMaxRange(range),
                length: followingToken.range.location - NSMaxRange(range)
            )
            let separator = (text as NSString).substring(with: separatorRange)
            let isWhitespaceConnected = !separator.isEmpty
                && separator.unicodeScalars.allSatisfy(CharacterSet.whitespaces.contains)
            if isWhitespaceConnected,
               followingToken.role == .noun || followingToken.role == .adjective {
                return false
            }
        }

        let candidate = (text as NSString).substring(with: range).lowercased()
        let candidateAnalysis = TextLinguistics.analyze(
            candidate,
            features: [.roles],
            grouping: .words
        )
        guard candidateAnalysis.availableFeatures.contains(.roles) else { return true }
        return candidateAnalysis.tokens.last?.inflection != .plural
    }

    private static func expression(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }
}
