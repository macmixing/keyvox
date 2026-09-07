import Foundation

/// Structural language-tag validation, without a language vocabulary or default.
enum ModelLanguageIdentifier {
    static func base(_ value: String) -> String? {
        let normalized = value.replacingOccurrences(of: "_", with: "-")
        guard normalized.range(of: #"\A[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*\z"#,
                               options: .regularExpression) != nil else { return nil }
        return normalized.split(separator: "-").first.map { $0.lowercased() }
    }
}
