import Foundation

enum NumberEvidenceRepairSupport {
    typealias Edit = (Range<String.Index>, String)

    static func applying(_ edits: [Edit], to text: String) -> String {
        guard !edits.isEmpty else { return text }

        var repaired = text
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    static func spacedReplacement(_ text: String) -> String {
        " \(text) "
    }

    static func canRestoreOriginalGap(originalGap: String, rewrittenSeparator: String) -> Bool {
        guard RepairTokenization.wordTokens(in: rewrittenSeparator).isEmpty,
              originalGap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return false
        }

        return originalGap.firstNonWhitespace == rewrittenSeparator.firstNonWhitespace
    }

    static func containsCurrencySymbol(in tokens: [RepairWordToken], text: String) -> Bool {
        tokens.contains { token in
            let prefix = text[..<token.range.lowerBound].suffix(4)
            return CurrencyUnits.symbols.contains { symbol in
                prefix.hasSuffix(symbol)
            }
        }
    }

    static func currencyReplacement(
        originalRun: [RepairWordToken],
        rewrittenRun: [RepairWordToken],
        replacementRange: Range<String.Index>,
        rewritten: String
    ) -> String? {
        guard let unit = originalRun.compactMap({ CurrencyUnits.unit(for: $0.normalized) }).first(where: { $0.scale == .major }),
              rewrittenRun.count == 1,
              rewrittenRun[0].text.allSatisfy(\.isNumber),
              containsCurrencySymbol(in: rewrittenRun, text: rewritten) == false else {
            return nil
        }

        let originalText = String(rewritten[replacementRange])
        let leadingWhitespace = String(originalText.prefix(while: \.isWhitespace))
        let suffix = String(rewritten[rewrittenRun[0].range.upperBound..<replacementRange.upperBound])
        return "\(leadingWhitespace)\(unit.symbol)\(rewrittenRun[0].text)\(suffix)"
    }

    static func log(_ message: String) {
        #if DEBUG
        NSLog("[NumberEvidenceRepair] %@", message)
        #endif
    }

    static func debugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

private extension String {
    var firstNonWhitespace: Character? {
        first { !$0.isWhitespace }
    }
}
