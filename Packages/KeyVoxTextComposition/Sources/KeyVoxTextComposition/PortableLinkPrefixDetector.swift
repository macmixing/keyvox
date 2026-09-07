import Foundation

/// Recognizes URI and DNS syntax without a language-specific domain dictionary.
/// It does not perform network lookups or claim that a destination exists.
package enum PortableLinkPrefixDetector {
    package static func startsWithLink(_ text: String) -> Bool {
        let token = String(text.prefix(while: { !$0.isWhitespace }))
        guard !token.isEmpty else { return false }
        if isLink(token) { return true }
        // A link can end before adjacent prose punctuation. The detector consumes
        // a prefix, so punctuation outside a valid URI need not invalidate it.
        for boundary in token.indices where token[boundary].isPunctuation {
            if isLink(String(token[..<boundary])) { return true }
        }
        return false
    }

    private static func isLink(_ token: String) -> Bool {
        if let components = URLComponents(string: token),
           components.scheme != nil,
           components.url != nil {
            return components.host?.isEmpty == false || !components.path.isEmpty
        }

        guard let components = URLComponents(string: "//" + token),
              components.url != nil,
              let host = components.host else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count > 1, labels.allSatisfy(validLabel),
              let suffix = labels.last,
              suffix.contains(where: \.isLetter) else { return false }
        return true
    }

    private static func validLabel(_ label: Substring) -> Bool {
        guard let first = label.first, let last = label.last,
              first.isLetter || first.isNumber,
              last.isLetter || last.isNumber else { return false }
        return label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
