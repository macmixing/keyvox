import Foundation

struct ListPatternMarkerParser {
    private static let spokenNumberPattern =
        "one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve"

    private static let markerRegex: NSRegularExpression = {
        let pattern =
            "(?i)(^|[\\s,;:])" +
            "(?:(\\d{1,2})|(\(spokenNumberPattern)))" +
            "(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z])))"
        return try! NSRegularExpression(pattern: pattern)
    }()
    private static let markerAttachedToDomainRegex: NSRegularExpression = {
        let pattern =
            "(?i)(?:[A-Z0-9\\-]+(?:\\.[A-Z0-9\\-]+)*\\.[A-Z]{2,})" +
            "((?:\\d{1,2})|(?:\(spokenNumberPattern)))" +
            "(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z])))"
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

            if digitRange.location != NSNotFound {
                let token = nsText.substring(with: digitRange)
                markerNumber = Int(token)
                markerTokenStart = digitRange.location
            } else if wordRange.location != NSNotFound {
                let token = nsText.substring(with: wordRange).lowercased()
                markerNumber = spokenNumberMap[token]
                markerTokenStart = wordRange.location
            } else {
                return nil
            }

            guard let markerNumber else { return nil }
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
}
