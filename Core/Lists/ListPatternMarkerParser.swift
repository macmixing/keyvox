import Foundation

struct ListPatternMarkerParser {
    private static let markerRegex: NSRegularExpression = {
        let pattern = "(?i)(^|[\\s,;:])(?:(\\d{1,2})|(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve))(?:\\s*[\\.\\)\\:\\-,])?\\s+"
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
        let matches = Self.markerRegex.matches(in: text, options: [], range: range)

        return matches.compactMap { match -> ListPatternMarker? in
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
            return ListPatternMarker(
                number: markerNumber,
                markerTokenStart: markerTokenStart,
                contentStart: match.range.location + match.range.length
            )
        }
    }
}
