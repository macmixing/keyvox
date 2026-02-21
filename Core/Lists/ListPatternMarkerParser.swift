import Foundation

struct ListPatternMarkerParser {
    private static let markerTokenPattern = #"(?:\d+|[A-Z]+(?:-[A-Z]+)?)"#

    private static let leadingMarkerRegex: NSRegularExpression = {
        let pattern = "(?i)^\\s*(\(markerTokenPattern))"
        return try! NSRegularExpression(pattern: pattern)
    }()
    private static let markerRegex: NSRegularExpression = {
        let pattern =
            "(?i)(?:^|(?<=[\\s,;:]))" +
            "(\(markerTokenPattern))" +
            "(?=(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z]))|\(WebsiteNormalizer.attachedDomainLookaheadPattern)))"
        return try! NSRegularExpression(pattern: pattern)
    }()
    private static let markerAttachedToDomainRegex: NSRegularExpression = {
        let pattern =
            "(?i)(?:[A-Z0-9\\-]+(?:\\.[A-Z0-9\\-]+)*\\.[A-Z]{2,})" +
            "(\(markerTokenPattern))" +
            "(?=(?:\\s+|\\s*[\\.\\)\\:\\-,](?:\\s+|(?=[A-Za-z]))))"
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

    private static let spokenNumberFormatterLock = NSLock()
    private static let spokenNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func parseMarkerValue(_ rawToken: String) -> Int? {
        let token = rawToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !token.isEmpty else { return nil }

        if token.allSatisfy(\.isNumber) {
            guard let value = Int(token), value > 0 else { return nil }
            return value
        }

        spokenNumberFormatterLock.lock()
        let parsed = spokenNumberFormatter.number(from: token)
        spokenNumberFormatterLock.unlock()
        guard let parsed else { return nil }

        let value = parsed.intValue
        guard value > 0 else { return nil }

        spokenNumberFormatterLock.lock()
        let roundTrip = spokenNumberFormatter.string(from: NSNumber(value: value))
        spokenNumberFormatterLock.unlock()
        guard let roundTrip else { return nil }

        guard normalizedSpokenToken(token) == normalizedSpokenToken(roundTrip) else {
            return nil
        }

        return value
    }

    static func hasExplicitDelimitedMarkerPrefix(in text: String) -> Bool {
        guard let marker = leadingMarker(in: text) else { return false }
        let nsText = text as NSString
        let suffixStart = marker.tokenRange.location + marker.tokenRange.length
        let suffixLength = max(0, nsText.length - suffixStart)
        guard suffixLength > 0 else { return false }
        let suffix = nsText.substring(with: NSRange(location: suffixStart, length: suffixLength))
        let trimmed = suffix.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        return ".):-,".contains(first)
    }

    static func hasLeadingListMarkerPrefix(in text: String) -> Bool {
        guard let marker = leadingMarker(in: text) else { return false }
        let nsText = text as NSString
        var index = marker.tokenRange.location + marker.tokenRange.length
        let length = nsText.length

        var hadRequiredWhitespace = false
        while index < length {
            let character = nsText.substring(with: NSRange(location: index, length: 1))
            guard character == " " || character == "\t" else { break }
            hadRequiredWhitespace = true
            index += 1
        }

        if index < length {
            let delimiter = nsText.substring(with: NSRange(location: index, length: 1))
            if ".):-,".contains(delimiter) {
                index += 1
                while index < length {
                    let character = nsText.substring(with: NSRange(location: index, length: 1))
                    guard character == " " || character == "\t" else { break }
                    hadRequiredWhitespace = true
                    index += 1
                }
            }
        }

        return hadRequiredWhitespace && index < length
    }

    func markers(in text: String) -> [ListPatternMarker] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let primaryMatches = Self.markerRegex.matches(in: text, options: [], range: range)
        let attachedMatches = Self.markerAttachedToDomainRegex.matches(in: text, options: [], range: range)
        let oneForOneRanges = Self.oneForOneRegex
            .matches(in: text, options: [], range: range)
            .map(\.range)

        var markers: [ListPatternMarker] = primaryMatches.compactMap { match -> ListPatternMarker? in
            let tokenRange = match.range(at: 1)
            guard tokenRange.location != NSNotFound else { return nil }

            guard let resolved = resolvedMarker(in: nsText, tokenRange: tokenRange) else {
                return nil
            }

            if resolved.isDigitToken && isLikelyTimeComponent(at: resolved.markerTokenStart, in: nsText) {
                return nil
            }
            if resolved.isDigitToken && isLikelyCompactClockTime(token: resolved.token, contentStart: resolved.contentStart, in: nsText) {
                return nil
            }
            if resolved.number == 1,
               oneForOneRanges.contains(where: { NSLocationInRange(resolved.markerTokenStart, $0) }) {
                return nil
            }

            return ListPatternMarker(
                number: resolved.number,
                markerTokenStart: resolved.markerTokenStart,
                contentStart: resolved.contentStart
            )
        }

        markers.append(contentsOf: attachedMatches.compactMap { match -> ListPatternMarker? in
            let tokenRange = match.range(at: 1)
            guard tokenRange.location != NSNotFound else { return nil }
            guard let resolved = resolvedMarker(in: nsText, tokenRange: tokenRange) else {
                return nil
            }
            if resolved.isDigitToken && isLikelyCompactClockTime(token: resolved.token, contentStart: resolved.contentStart, in: nsText) {
                return nil
            }
            if resolved.number == 1,
               oneForOneRanges.contains(where: { NSLocationInRange(resolved.markerTokenStart, $0) }) {
                return nil
            }

            return ListPatternMarker(
                number: resolved.number,
                markerTokenStart: resolved.markerTokenStart,
                contentStart: resolved.contentStart
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

    private static func normalizedSpokenToken(_ token: String) -> String {
        token
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedMarker(
        in nsText: NSString,
        tokenRange: NSRange
    ) -> (number: Int, markerTokenStart: Int, contentStart: Int, token: String, isDigitToken: Bool)? {
        let token = nsText.substring(with: tokenRange).lowercased()
        if let number = Self.parseMarkerValue(token),
           let contentStart = contentStart(afterTokenRange: tokenRange, in: nsText) {
            return (
                number: number,
                markerTokenStart: tokenRange.location,
                contentStart: contentStart,
                token: token,
                isDigitToken: token.allSatisfy(\.isNumber)
            )
        }

        // Handle attached compact-domain cases like "threekeyvox.app":
        // recover a valid marker prefix and leave the domain token as content.
        let tokenNSString = token as NSString
        let trailingText = nsText.substring(from: tokenRange.location + tokenRange.length)

        for splitOffset in stride(from: tokenNSString.length - 1, through: 1, by: -1) {
            let prefix = tokenNSString.substring(to: splitOffset)
            guard let number = Self.parseMarkerValue(prefix) else { continue }

            let suffix = tokenNSString.substring(from: splitOffset)
            let combined = suffix + trailingText
            guard WebsiteNormalizer.hasLeadingCompactDomainToken(in: combined) else { continue }

            let prefixRange = NSRange(location: tokenRange.location, length: splitOffset)
            guard let contentStart = contentStart(afterTokenRange: prefixRange, in: nsText) else { continue }

            return (
                number: number,
                markerTokenStart: tokenRange.location,
                contentStart: contentStart,
                token: prefix.lowercased(),
                isDigitToken: prefix.allSatisfy(\.isNumber)
            )
        }

        return nil
    }

    private func contentStart(afterTokenRange tokenRange: NSRange, in nsText: NSString) -> Int? {
        var index = tokenRange.location + tokenRange.length
        let length = nsText.length

        var consumedDelimiter = false
        while index < length {
            let character = nsText.substring(with: NSRange(location: index, length: 1))
            guard character.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else { break }
            consumedDelimiter = true
            index += 1
        }

        if index < length {
            let delimiter = nsText.substring(with: NSRange(location: index, length: 1))
            if ".):-,".contains(delimiter) {
                consumedDelimiter = true
                index += 1
                while index < length {
                    let character = nsText.substring(with: NSRange(location: index, length: 1))
                    guard character.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else { break }
                    consumedDelimiter = true
                    index += 1
                }
            }
        }

        if consumedDelimiter {
            return index
        }

        guard index < length else { return nil }
        let previewLength = min(120, length - index)
        let preview = nsText.substring(with: NSRange(location: index, length: previewLength))
        return WebsiteNormalizer.hasLeadingCompactDomainToken(in: preview) ? index : nil
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

    private func isLikelyCompactClockTime(token: String, contentStart: Int, in nsText: NSString) -> Bool {
        guard token.allSatisfy(\.isNumber), (3...4).contains(token.count) else { return false }

        let hour: Int
        let minute: Int
        if token.count == 3 {
            hour = Int(token.prefix(1)) ?? -1
            minute = Int(token.suffix(2)) ?? -1
        } else {
            hour = Int(token.prefix(2)) ?? -1
            minute = Int(token.suffix(2)) ?? -1
        }
        guard (1...12).contains(hour), (0...59).contains(minute) else { return false }
        guard contentStart < nsText.length else { return false }

        let previewLength = min(12, nsText.length - contentStart)
        let preview = nsText.substring(with: NSRange(location: contentStart, length: previewLength))
        return preview.range(of: #"(?i)^(?:a\.?m\.?|p\.?m\.?)\b"#, options: .regularExpression) != nil
    }

    private static func leadingMarker(in text: String) -> (value: Int, tokenRange: NSRange)? {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = leadingMarkerRegex.firstMatch(in: text, options: [], range: range) else { return nil }
        let tokenRange = match.range(at: 1)
        guard tokenRange.location != NSNotFound else { return nil }
        let token = nsText.substring(with: tokenRange)
        guard let value = parseMarkerValue(token) else { return nil }
        return (value, tokenRange)
    }
}
