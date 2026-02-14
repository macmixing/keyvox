import Foundation

struct ListPatternDetector {
    private struct Marker {
        let number: Int
        let markerTokenStart: Int
        let contentStart: Int
    }

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

    func detectList(in text: String) -> DetectedList? {
        let markers = markers(in: text)
        guard markers.count >= 2 else { return nil }
        guard let bestRun = bestMonotonicRun(from: markers), bestRun.count >= 2 else { return nil }

        let nsText = text as NSString
        let firstMarkerStart = bestRun[0].markerTokenStart
        var items: [DetectedListItem] = []
        var trailingText = ""

        for index in 0..<bestRun.count {
            let marker = bestRun[index]
            let end = index + 1 < bestRun.count ? bestRun[index + 1].markerTokenStart : nsText.length
            guard end > marker.contentStart else { return nil }

            let rawContent = nsText.substring(with: NSRange(location: marker.contentStart, length: end - marker.contentStart))
            let content: String
            if index == bestRun.count - 1 {
                let split = splitLastItemAndTrailing(rawContent)
                guard let cleanedItem = sanitizeItemContent(split.itemText) else { return nil }
                content = cleanedItem
                trailingText = split.trailingText
            } else {
                guard let cleanedItem = sanitizeItemContent(rawContent) else { return nil }
                content = cleanedItem
            }
            items.append(DetectedListItem(spokenIndex: marker.number, content: content))
        }

        guard items.count >= 2 else { return nil }
        let leadingText = nsText
            .substring(to: max(0, firstMarkerStart))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return DetectedList(leadingText: leadingText, items: items, trailingText: trailingText)
    }

    private func markers(in text: String) -> [Marker] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = Self.markerRegex.matches(in: text, options: [], range: range)

        return matches.compactMap { match -> Marker? in
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
            return Marker(number: markerNumber, markerTokenStart: markerTokenStart, contentStart: match.range.location + match.range.length)
        }
    }

    private func bestMonotonicRun(from markers: [Marker]) -> [Marker]? {
        guard !markers.isEmpty else { return nil }

        var best: [Marker] = []
        var current: [Marker] = [markers[0]]

        for marker in markers.dropFirst() {
            if let previous = current.last, marker.number == previous.number + 1 {
                current.append(marker)
            } else {
                if current.count > best.count {
                    best = current
                }
                current = [marker]
            }
        }

        if current.count > best.count {
            best = current
        }

        return best.count >= 2 ? best : nil
    }

    private func sanitizeItemContent(_ raw: String) -> String? {
        var cleaned = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        cleaned = cleaned
            .replacingOccurrences(of: "^(?i)(and|then|next)\\b[\\s,:-]*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)[\\s,:-]*(and|then|next)$", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r.,;:!?-"))

        guard cleaned.count >= 2 else { return nil }
        guard cleaned.rangeOfCharacter(from: .letters) != nil else { return nil }

        return cleaned
    }

    private func splitLastItemAndTrailing(_ raw: String) -> (itemText: String, trailingText: String) {
        let normalized = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return ("", "")
        }

        // First pass: split on the first clear sentence boundary.
        if let split = firstRegexSplit(normalized, pattern: #"(?i)^(.+?[.!?])\s+(.+)$"#) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            if itemWordCount >= 3 && trailingWordCount >= 3 && !startsLikeListMarker(split.1) {
                return (split.0, split.1)
            }
        }

        // Second pass: split long causal commentary off the last list item.
        if let split = firstRegexSplit(
            normalized,
            pattern: #"(?i)^(.{8,}?)\s+(because|since|as)\s+(.+)$"#
        ) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            if itemWordCount >= 4 && trailingWordCount >= 4 && !startsLikeListMarker(split.1) {
                return (split.0, split.1)
            }
        }

        // Prefer explicit sentence break before common post-list transition cues.
        if let match = normalized.range(
            of: #"(?i)^(.+?[.!?])\s+((?:and|also|now|okay|ok|so|then|next|finally|after that|anyway|anyways)\b.*)$"#,
            options: .regularExpression
        ) {
            let full = String(normalized[match])
            if let split = firstRegexSplit(full, pattern: #"(?i)^(.+?[.!?])\s+(.+)$"#) {
                return (split.0, split.1)
            }
        }

        // Fallback for speech without hard punctuation ("... and now ...").
        if let split = firstRegexSplit(
            normalized,
            pattern: #"(?i)^(.{8,}?)\s+(and\s+(?:now|then|i|we)|now|okay|ok|so|anyway|anyways|also|i\s+(?:need|want|have|should)|we\s+(?:need|want|have|should))\s+(.+)$"#
        ) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            if itemWordCount >= 3 && trailingWordCount >= 3 {
                return (split.0, split.1)
            }
        }

        return (normalized, "")
    }

    private func firstRegexSplit(_ text: String, pattern: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        // Pattern variants used here always return item in group 1 and trailing tail in last group.
        let itemRange = match.range(at: 1)
        let tailRange = match.range(at: match.numberOfRanges - 1)
        guard itemRange.location != NSNotFound, tailRange.location != NSNotFound else { return nil }

        let item = nsText.substring(with: itemRange).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = nsText.substring(with: tailRange).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty, !tail.isEmpty else { return nil }
        return (item, tail)
    }

    private func startsLikeListMarker(_ text: String) -> Bool {
        let normalized = text
            .replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
            .lowercased()

        return normalized.range(
            of: #"^(?:\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?:\s*[.):\-,])?\s+"#,
            options: .regularExpression
        ) != nil
    }
}
