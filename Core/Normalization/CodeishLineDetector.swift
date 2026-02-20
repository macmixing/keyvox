import Foundation

enum CodeishLineDetector {
    private static let codeOperators = ["==", "!=", "<=", ">=", "=>", "->", "::", "&&", "||", "++", "--"]
    private static let assignmentLikeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*"#,
        options: []
    )

    static func isLikelyCodeishLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        if line.contains("`") { return true }
        if codeOperators.contains(where: line.contains) { return true }

        if let assignmentRegex = assignmentLikeRegex {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if assignmentRegex.firstMatch(in: line, options: [], range: range) != nil {
                return true
            }
        }

        if line.contains(";") {
            let hasBracesOrBrackets = line.contains("{") || line.contains("}") || line.contains("[") || line.contains("]")
            if hasBracesOrBrackets {
                return true
            }
        }

        return false
    }
}
