import Foundation

extension MathExpressionNormalizer {
    func normalizedExponentToken(_ token: String) -> String? {
        let trimmed = token
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!?"))
        guard !trimmed.isEmpty else { return nil }
        let exponentToken = trimmed.replacingOccurrences(
            of: #"\s+power$"#,
            with: "",
            options: .regularExpression
        )
        guard !exponentToken.isEmpty else { return nil }

        if let regex = Self.numericOrdinalExponentRegex {
            let nsToken = exponentToken as NSString
            let range = NSRange(location: 0, length: nsToken.length)
            if let match = regex.firstMatch(in: exponentToken, options: [], range: range) {
                return nsToken.substring(with: match.range(at: 1))
            }
        }

        return Self.parseOrdinalWordExponent(exponentToken)
    }

    private static func parseOrdinalWordExponent(_ text: String) -> String? {
        let normalized = normalizedOrdinalLookupKey(text)
        guard !normalized.isEmpty else { return nil }

        if let direct = spellOutNumberParser.number(from: normalized)?.intValue, direct > 0 {
            return String(direct)
        }

        let parts = normalized.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }

        let prefix = parts.dropLast().joined(separator: " ")
        let suffix = parts.last ?? ""
        guard let prefixValue = spellOutNumberParser.number(from: prefix)?.intValue,
              prefixValue > 0,
              let suffixValue = spellOutNumberParser.number(from: suffix)?.intValue,
              suffixValue > 0 else {
            return nil
        }

        return String(prefixValue + suffixValue)
    }

    private static func normalizedOrdinalLookupKey(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!? ").union(.whitespacesAndNewlines))
    }
}
