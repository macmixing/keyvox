import Foundation

struct ListPatternMarkerParser {
    private static let spokenNumberPattern =
        "one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve"

    private static let markerRegex: NSRegularExpression = {
        let pattern =
            "(?i)(^|[\\s,;:])" +
            "(?:(\\d{1,2})|(\(spokenNumberPattern)))" +
            "(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z]))|\(WebsiteNormalizer.attachedDomainLookaheadPattern))"
        return try! NSRegularExpression(pattern: pattern)
    }()
    private static let markerAttachedToDomainRegex: NSRegularExpression = {
        let pattern =
            "(?i)(?:[A-Z0-9\\-]+(?:\\.[A-Z0-9\\-]+)*\\.[A-Z]{2,})" +
            "((?:\\d{1,2})|(?:\(spokenNumberPattern)))" +
            "(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z])))"
        return try! NSRegularExpression(pattern: pattern)
    }()
    private static let spokenTwoHomophoneRegex: NSRegularExpression = {
        let pattern =
            "(?i)(^|[\\s,;:])" +
            "(to)" +
            "(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z]))|\(WebsiteNormalizer.attachedDomainLookaheadPattern))"
        return try! NSRegularExpression(pattern: pattern)
    }()
    private static let oneForOneRegex: NSRegularExpression = {
        let pattern = #"(?i)\b(?:one|1)\s+for\s+(?:one|1)\b"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    private let spokenNumberMap: [String: Int] = [
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
        "ten": 10,
        "eleven": 11,
        "twelve": 12,
    ]

    func markers(in text: String) -> [ListPatternMarker] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let primaryMatches = Self.markerRegex.matches(in: text, options: [], range: range)
        let attachedMatches = Self.markerAttachedToDomainRegex.matches(in: text, options: [], range: range)
        let oneForOneRanges = Self.oneForOneRegex
            .matches(in: text, options: [], range: range)
            .map(\.range)

        var markers: [ListPatternMarker] = primaryMatches.compactMap { match -> ListPatternMarker? in
            let digitRange = match.range(at: 2)
            let wordRange = match.range(at: 3)

            let markerNumber: Int?
            let markerTokenStart: Int
            let isDigitToken: Bool

            if digitRange.location != NSNotFound {
                let token = nsText.substring(with: digitRange)
                markerNumber = Int(token)
                markerTokenStart = digitRange.location
                isDigitToken = true
            } else if wordRange.location != NSNotFound {
                let token = nsText.substring(with: wordRange).lowercased()
                markerNumber = spokenNumberMap[token]
                markerTokenStart = wordRange.location
                isDigitToken = false
            } else {
                return nil
            }

            guard let markerNumber else { return nil }
            if isDigitToken && isLikelyTimeComponent(at: markerTokenStart, in: nsText) {
                return nil
            }
            if markerNumber == 1,
               oneForOneRanges.contains(where: { NSLocationInRange(markerTokenStart, $0) }) {
                return nil
            }
            return ListPatternMarker(
                number: markerNumber,
                markerTokenStart: markerTokenStart,
                contentStart: match.range.location + match.range.length
            )
        }

        markers.append(contentsOf: attachedMatches.compactMap { match -> ListPatternMarker? in
            let tokenRange = match.range(at: 1)
            guard tokenRange.location != NSNotFound else { return nil }

            let token = nsText.substring(with: tokenRange).lowercased()
            let markerNumber = Int(token) ?? spokenNumberMap[token]
            guard let markerNumber else { return nil }

            let markerTokenStart = tokenRange.location
            if markerNumber == 1,
               oneForOneRanges.contains(where: { NSLocationInRange(markerTokenStart, $0) }) {
                return nil
            }

            return ListPatternMarker(
                number: markerNumber,
                markerTokenStart: markerTokenStart,
                contentStart: match.range.location + match.range.length
            )
        })

        let spokenTwoMatches = Self.spokenTwoHomophoneRegex.matches(in: text, options: [], range: range)
        markers.append(contentsOf: spokenTwoMatches.compactMap { match -> ListPatternMarker? in
            let tokenRange = match.range(at: 2)
            guard tokenRange.location != NSNotFound else { return nil }

            let markerTokenStart = tokenRange.location
            guard let priorMarker = nearestPriorMarker(before: markerTokenStart, in: markers),
                  priorMarker.number == 1 else {
                return nil
            }

            guard looksLikeEmailListItemContent(
                in: nsText,
                contentStart: priorMarker.contentStart,
                markerTokenStart: markerTokenStart
            ) else {
                return nil
            }

            let contentStart = match.range.location + match.range.length
            guard looksLikeEmailListItemStart(in: nsText, from: contentStart) else {
                return nil
            }

            return ListPatternMarker(
                number: 2,
                markerTokenStart: markerTokenStart,
                contentStart: contentStart
            )
        })

        let sorted = markers.sorted {
            if $0.markerTokenStart != $1.markerTokenStart {
                return $0.markerTokenStart < $1.markerTokenStart
            }
            return $0.contentStart < $1.contentStart
        }

        var deduped: [ListPatternMarker] = []
        deduped.reserveCapacity(sorted.count)
        for marker in sorted where deduped.last?.markerTokenStart != marker.markerTokenStart {
            deduped.append(marker)
        }

        return deduped
    }

    private func nearestPriorMarker(before index: Int, in markers: [ListPatternMarker]) -> ListPatternMarker? {
        markers
            .filter { $0.markerTokenStart < index }
            .max { $0.markerTokenStart < $1.markerTokenStart }
    }

    private func looksLikeEmailListItemContent(in nsText: NSString, contentStart: Int, markerTokenStart: Int) -> Bool {
        guard contentStart < markerTokenStart, markerTokenStart <= nsText.length else { return false }

        let rawRange = NSRange(location: contentStart, length: markerTokenStart - contentStart)
        let rawContent = nsText.substring(with: rawRange)
        let collapsed = rawContent
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return false }

        let punctuationStripped = collapsed
            .replacingOccurrences(
                of: #"[\"'”’\)\]\}]*[.,;:!?…]+[\"'”’\)\]\}]*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let emailLikePattern =
            #"(?i)^(?:[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}|[A-Z0-9._%+'\-]+(?:\s+[A-Z0-9._%+'\-]+){0,3}\s+at\s+[A-Z0-9\-]+(?:\.[A-Z0-9\-]+)+)$"#
        if punctuationStripped.range(of: emailLikePattern, options: .regularExpression) != nil {
            return true
        }
        return WebsiteNormalizer.isCompactDomainToken(punctuationStripped)
    }

    private func looksLikeEmailListItemStart(in nsText: NSString, from contentStart: Int) -> Bool {
        guard contentStart < nsText.length else { return false }

        let previewLength = min(100, nsText.length - contentStart)
        let preview = nsText.substring(with: NSRange(location: contentStart, length: previewLength))
        let emailLikePattern = #"(?i)^\s*(?:[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}|[A-Z0-9._%+'\-]+(?:\s+[A-Z0-9._%+'\-]+){0,3}\s+at\s+[A-Z0-9\-]+(?:\.[A-Z0-9\-]+)+)\b"#
        if preview.range(of: emailLikePattern, options: .regularExpression) != nil {
            return true
        }
        return WebsiteNormalizer.hasLeadingCompactDomainToken(in: preview)
    }

    private func isLikelyTimeComponent(at markerTokenStart: Int, in nsText: NSString) -> Bool {
        guard markerTokenStart >= 2 else { return false }

        let delimiterIndex = markerTokenStart - 1
        let delimiter = nsText.substring(with: NSRange(location: delimiterIndex, length: 1))
        guard delimiter == ":" || delimiter == "." || delimiter == "-" else {
            return false
        }

        let hourIndex = delimiterIndex - 1
        let hourCharacter = nsText.substring(with: NSRange(location: hourIndex, length: 1))
        return hourCharacter.range(of: #"^\d$"#, options: .regularExpression) != nil
    }
}
