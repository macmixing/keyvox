import Foundation

enum PocketTTSTextNormalizer {
    private static let repeatedChevronPattern = #">\s*>\s*>+"#
    private static let urlPattern = #"https?://\S+"#
    private static let emailPattern = #"\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b"#
    private static let markdownLinkPattern = #"\[([^\]]+)\]\((https?://[^)]+)\)"#
    private static let markdownHeadingPattern = #"(?m)^\s{0,3}#{1,6}\s*"#
    private static let fencedCodeBlockPattern = #"(?s)```.*?```"#
    private static let inlineCodePattern = #"`([^`]+)`"#
    private static let dollarAmountPattern = #"\$([0-9]+(?:\.[0-9]+)?)"#
    private static let euroAmountPattern = #"€([0-9]+(?:\.[0-9]+)?)"#
    private static let poundAmountPattern = #"£([0-9]+(?:\.[0-9]+)?)"#
    private static let percentPattern = #"([0-9]+(?:\.[0-9]+)?)%"#
    private static let timePattern = #"\b([0-9]{1,2}):([0-9]{2})(?:\s*([AaPp][Mm]))?\b"#
    private static let datePattern = #"\b([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})\b"#
    private static let versionPattern = #"\bv([0-9]+(?:\.[0-9]+){1,3})\b"#
    private static let slashJoinPattern = #"(?<=\p{L}|\p{N})/(?=\p{L}|\p{N})"#
    private static let hyphenJoinPattern = #"(?<=\p{L}|\p{N})\-(?=\p{L}|\p{N})"#
    private static let underscoreJoinPattern = #"(?<=\p{L}|\p{N})_(?=\p{L}|\p{N})"#
    private static let camelCaseBoundaryPattern = #"(?<=\p{Ll})(?=\p{Lu})"#
    private static let openAsidePattern = #"\s*[\(\[]\s*"#
    private static let closeAsidePattern = #"\s*[\)\]]\s*"#

    static func sanitize(_ text: String) -> String {
        var sanitized = text

        sanitized = sanitized.replacingOccurrences(of: "\u{2018}", with: "'")
        sanitized = sanitized.replacingOccurrences(of: "\u{2019}", with: "'")
        sanitized = sanitized.replacingOccurrences(of: "\u{201C}", with: "\"")
        sanitized = sanitized.replacingOccurrences(of: "\u{201D}", with: "\"")
        sanitized = sanitized.replacingOccurrences(of: "\u{2013}", with: "-")
        sanitized = sanitized.replacingOccurrences(of: "\u{2014}", with: " - ")
        sanitized = sanitized.replacingOccurrences(of: "\u{2026}", with: "...")
        sanitized = sanitized.replacingOccurrences(of: "&", with: " and ")

        sanitized = sanitized.replacingOccurrences(
            of: fencedCodeBlockPattern,
            with: " code block ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: markdownLinkPattern,
            with: "$1",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: markdownHeadingPattern,
            with: "",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: inlineCodePattern,
            with: "$1",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: repeatedChevronPattern,
            with: ", ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: urlPattern,
            with: " link ",
            options: [.regularExpression, .caseInsensitive]
        )
        sanitized = sanitized.replacingOccurrences(
            of: emailPattern,
            with: " email ",
            options: [.regularExpression, .caseInsensitive]
        )
        sanitized = sanitized.replacingOccurrences(
            of: dollarAmountPattern,
            with: "$1 dollars",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: euroAmountPattern,
            with: "$1 euros",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: poundAmountPattern,
            with: "$1 pounds",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: percentPattern,
            with: "$1 percent",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: timePattern,
            with: "$1 $2 $3",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: datePattern,
            with: "$1 $2 $3",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: ":",
            with: ". "
        )
        sanitized = sanitized.replacingOccurrences(
            of: versionPattern,
            with: "version $1",
            options: [.regularExpression, .caseInsensitive]
        )
        sanitized = sanitized.replacingOccurrences(
            of: openAsidePattern,
            with: ", ",
            options: .regularExpression
        )
        sanitized = normalizeCloseAsides(in: sanitized)
        sanitized = sanitized.replacingOccurrences(
            of: slashJoinPattern,
            with: " ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: hyphenJoinPattern,
            with: " ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: underscoreJoinPattern,
            with: " ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: camelCaseBoundaryPattern,
            with: " ",
            options: .regularExpression
        )
        sanitized = normalizeListItemTerminalPeriods(in: sanitized)
        sanitized = sanitized.replacingOccurrences(
            of: #"[^\p{L}\p{N}\s\.,!\?;'"\/\-\)\n]"#,
            with: " ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"\s*,\s*,+"#,
            with: ", ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"\s+,([.!?])"#,
            with: "$1",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"\.{4,}"#,
            with: "...",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"(?<!\.)\.\.(?!\.)"#,
            with: ".",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"[ \t]+"#,
            with: " ",
            options: .regularExpression
        )

        return sanitized
    }

    private static func normalizeListItemTerminalPeriods(in text: String) -> String {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { normalizeListItemTerminalPeriod(in: String($0)) }
            .joined(separator: "\n")
    }

    private static func normalizeListItemTerminalPeriod(in line: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLine.isEmpty == false else { return line }

        let isNumberedListItem = trimmedLine.range(
            of: #"^\d+[\.\)]\s+"#,
            options: .regularExpression
        ) != nil
        let isBulletedListItem = trimmedLine.range(
            of: #"^[-*•]\s+"#,
            options: .regularExpression
        ) != nil

        guard isNumberedListItem || isBulletedListItem else { return line }

        let normalizedMarkerLine = line.replacingOccurrences(
            of: #"^(\s*)[\*•](\s+)"#,
            with: "$1-$2",
            options: .regularExpression
        )

        let withoutTrailingWhitespace = normalizedMarkerLine.replacingOccurrences(
            of: #"\s+$"#,
            with: "",
            options: .regularExpression
        )

        if withoutTrailingWhitespace.range(
            of: #"[,;:\.!?]+$"#,
            options: .regularExpression
        ) != nil {
            return withoutTrailingWhitespace.replacingOccurrences(
                of: #"[,;:\.!?]+$"#,
                with: ".",
                options: .regularExpression
            )
        }

        return withoutTrailingWhitespace + "."
    }

    private static func normalizeCloseAsides(in text: String) -> String {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { normalizeCloseAsidesInLine(String($0)) }
            .joined(separator: "\n")
    }

    private static func normalizeCloseAsidesInLine(_ line: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let isNumberedListItem = trimmedLine.range(
            of: #"^\d+\)\s+"#,
            options: .regularExpression
        ) != nil

        guard isNumberedListItem else {
            return line.replacingOccurrences(
                of: closeAsidePattern,
                with: ", ",
                options: .regularExpression
            )
        }

        let listMarkerPattern = #"^(\s*\d+\))(\s+)(.*)$"#
        guard let range = line.range(
            of: listMarkerPattern,
            options: .regularExpression
        ) else {
            return line.replacingOccurrences(
                of: closeAsidePattern,
                with: ", ",
                options: .regularExpression
            )
        }

        let matchedLine = String(line[range])
        let capturePattern = try? NSRegularExpression(pattern: listMarkerPattern)
        guard
            let regex = capturePattern,
            let match = regex.firstMatch(
                in: matchedLine,
                range: NSRange(matchedLine.startIndex..., in: matchedLine)
            ),
            let markerRange = Range(match.range(at: 1), in: matchedLine),
            let spacingRange = Range(match.range(at: 2), in: matchedLine),
            let contentRange = Range(match.range(at: 3), in: matchedLine)
        else {
            return line.replacingOccurrences(
                of: closeAsidePattern,
                with: ", ",
                options: .regularExpression
            )
        }

        let marker = String(matchedLine[markerRange])
        let spacing = String(matchedLine[spacingRange])
        let content = String(matchedLine[contentRange]).replacingOccurrences(
            of: closeAsidePattern,
            with: ", ",
            options: .regularExpression
        )

        return marker + spacing + content
    }
}
