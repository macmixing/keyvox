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
        let detection: (run: [Marker], renumberSequentially: Bool)?
        if let bestRun = bestMonotonicRun(from: markers, in: text), bestRun.count >= 2 {
            detection = (bestRun, false)
        } else if let restartedRun = restartedOneRunAcrossParagraphBreaks(from: markers, in: text),
                  restartedRun.count >= 2 {
            detection = (restartedRun, true)
        } else {
            detection = nil
        }
        guard let detection else { return nil }
        let bestRun = detection.run

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
            let spokenIndex = detection.renumberSequentially ? (index + 1) : marker.number
            items.append(DetectedListItem(spokenIndex: spokenIndex, content: content))
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

    private func bestMonotonicRun(from markers: [Marker], in text: String) -> [Marker]? {
        guard !markers.isEmpty else { return nil }
        let nsText = text as NSString

        // Build best monotonic subsequence ending at each marker, so we can
        // skip noise markers (e.g. incidental "one" in prose) and still keep
        // the intended 1->2->3 list flow.
        var bestEndingAt = Array(repeating: [Marker](), count: markers.count)

        for i in markers.indices {
            var bestForCurrent: [Marker] = [markers[i]]
            for j in 0..<i where markers[i].number == markers[j].number + 1 {
                let previousRun = bestEndingAt[j]
                guard !previousRun.isEmpty else { continue }
                let candidate = previousRun + [markers[i]]
                if shouldPrefer(run: candidate, over: bestForCurrent, in: nsText) {
                    bestForCurrent = candidate
                }
            }
            bestEndingAt[i] = bestForCurrent
        }

        var best: [Marker] = []
        for run in bestEndingAt where shouldPrefer(run: run, over: best, in: nsText) {
            best = run
        }

        return best.count >= 2 ? best : nil
    }

    private func shouldPrefer(run candidate: [Marker], over existing: [Marker], in nsText: NSString) -> Bool {
        guard !candidate.isEmpty else { return false }
        guard !existing.isEmpty else { return true }

        if candidate.count != existing.count {
            return candidate.count > existing.count
        }

        let candidateStrength = runStrength(candidate, in: nsText)
        let existingStrength = runStrength(existing, in: nsText)
        if candidateStrength != existingStrength {
            return candidateStrength > existingStrength
        }

        let candidateStart = candidate.first?.markerTokenStart ?? 0
        let existingStart = existing.first?.markerTokenStart ?? 0
        return candidateStart > existingStart
    }

    private func runStrength(_ run: [Marker], in nsText: NSString) -> Int {
        run.reduce(0) { partial, marker in
            var score = partial
            if markerHasExplicitDelimiter(marker, in: nsText) { score += 2 }
            if markerHasBoundaryBefore(marker, in: nsText) { score += 1 }
            return score
        }
    }

    private func markerHasExplicitDelimiter(_ marker: Marker, in nsText: NSString) -> Bool {
        let spanLength = max(0, marker.contentStart - marker.markerTokenStart)
        guard spanLength > 0 else { return false }
        let span = nsText.substring(with: NSRange(location: marker.markerTokenStart, length: spanLength))
        let explicitPattern = #"(?i)^(?:\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s*[.\):\-,]"#
        return span.range(of: explicitPattern, options: .regularExpression) != nil
    }

    private func markerHasBoundaryBefore(_ marker: Marker, in nsText: NSString) -> Bool {
        guard marker.markerTokenStart > 0 else { return true }
        let prefix = nsText.substring(to: marker.markerTokenStart)
        let boundaryPattern = #"(?:^|[\n\r]|[.!?:;])\s*$"#
        return prefix.range(of: boundaryPattern, options: .regularExpression) != nil
    }

    // Paragraph chunking can restart list numbering context between chunks
    // (e.g. "one ...", "one ...", "one ..."). Recover list intent only when
    // those restarts are separated by explicit paragraph breaks.
    private func restartedOneRunAcrossParagraphBreaks(from markers: [Marker], in text: String) -> [Marker]? {
        guard markers.count >= 2 else { return nil }
        let nsText = text as NSString

        var best: [Marker] = []
        var current: [Marker] = []

        for marker in markers {
            guard marker.number == 1 else {
                if current.count > best.count { best = current }
                current = []
                continue
            }

            guard let previous = current.last else {
                current = [marker]
                continue
            }

            let gapStart = previous.contentStart
            let gapLength = max(0, marker.markerTokenStart - gapStart)
            let gap = nsText.substring(with: NSRange(location: gapStart, length: gapLength))
            if gap.contains("\n\n") {
                current.append(marker)
            } else {
                if current.count > best.count { best = current }
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
            .trimmingCharacters(in: .whitespacesAndNewlines)

        cleaned = stripTerminalPunctuation(in: cleaned)

        guard cleaned.count >= 2 else { return nil }
        guard cleaned.rangeOfCharacter(from: .letters) != nil else { return nil }

        return capitalizeFirstLetter(in: cleaned)
    }

    private func stripTerminalPunctuation(in text: String) -> String {
        text
            .replacingOccurrences(
                of: #"[\"'”’\)\]\}]*[.,;:!?…]+[\"'”’\)\]\}]*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func capitalizeFirstLetter(in text: String) -> String {
        guard let firstLetter = text.firstIndex(where: { $0.isLetter }) else { return text }
        var capitalized = text
        capitalized.replaceSubrange(firstLetter...firstLetter, with: String(text[firstLetter]).uppercased())
        return capitalized
    }

    private func splitLastItemAndTrailing(_ raw: String) -> (itemText: String, trailingText: String) {
        let paragraphToken = "__KVX_PARAGRAPH_BREAK__"
        let normalized = raw
            .replacingOccurrences(
                of: #"\n[ \t]*\n+"#,
                with: " \(paragraphToken) ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return ("", "")
        }

        // Prefer explicit sentence break before common post-list transition cues.
        if let match = normalized.range(
            of: #"(?i)^(.+?[.!?])\s+((?:and|also|now|okay|ok|so|then|next|finally|after that|after all that|anyway|anyways)\b.*)$"#,
            options: .regularExpression
        ) {
            let full = String(normalized[match])
            if let split = firstRegexSplit(full, pattern: #"(?i)^(.+?[.!?])\s+(.+)$"#) {
                return (
                    restoreParagraphBreaks(in: split.0, paragraphToken: paragraphToken),
                    restoreParagraphBreaks(in: split.1, paragraphToken: paragraphToken)
                )
            }
        }

        // Common Whisper shape for post-list continuation:
        // "... <last item>, and <new thought>"
        if let split = firstRegexSplit(
            normalized,
            pattern: #"(?i)^(.{8,}?),\s+((?:and\s+(?:now|then|i|we|everything|that|this|there|by|after)|after all that|now|okay|ok|so|anyway|anyways|also)\b.*)$"#
        ) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            if itemWordCount >= 3 && trailingWordCount >= 3 {
                return (
                    restoreParagraphBreaks(in: split.0, paragraphToken: paragraphToken),
                    restoreParagraphBreaks(in: split.1, paragraphToken: paragraphToken)
                )
            }
        }

        // Split long causal commentary off the last list item.
        if let split = firstRegexSplit(
            normalized,
            pattern: #"(?i)^(.{8,}?)\s+((?:and\s+)?(?:because|since|as)\s+.+)$"#
        ) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            let itemAlreadyContainsSentenceBoundary = split.0.range(
                of: #"(?i)[.!?]\s+\S"#,
                options: .regularExpression
            ) != nil
            if itemWordCount >= 2 &&
                trailingWordCount >= 3 &&
                !startsLikeListMarker(split.1) &&
                !itemAlreadyContainsSentenceBoundary {
                return (
                    restoreParagraphBreaks(in: split.0, paragraphToken: paragraphToken),
                    restoreParagraphBreaks(in: split.1, paragraphToken: paragraphToken)
                )
            }
        }

        // Fallback for speech without hard punctuation ("... and now ...").
        if let split = firstRegexSplit(
            normalized,
            pattern: #"(?i)^(.{8,}?)\s+((?:and\s+(?:now|then|i|we|by|after)|after all that|now|okay|ok|so|anyway|anyways|also|i\s+(?:need|want|have|should)|we\s+(?:need|want|have|should))\s+.+)$"#
        ) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            if itemWordCount >= 2 && trailingWordCount >= 3 {
                return (
                    restoreParagraphBreaks(in: split.0, paragraphToken: paragraphToken),
                    restoreParagraphBreaks(in: split.1, paragraphToken: paragraphToken)
                )
            }
        }

        // Final pass: split on a generic sentence boundary.
        if let split = firstRegexSplit(normalized, pattern: #"(?i)^(.+?[.!?])\s+(.+)$"#) {
            let itemWordCount = split.0.split(separator: " ").count
            let trailingWordCount = split.1.split(separator: " ").count
            if itemWordCount >= 3 && trailingWordCount >= 3 && !startsLikeListMarker(split.1) {
                return (
                    restoreParagraphBreaks(in: split.0, paragraphToken: paragraphToken),
                    restoreParagraphBreaks(in: split.1, paragraphToken: paragraphToken)
                )
            }
        }

        return (restoreParagraphBreaks(in: normalized, paragraphToken: paragraphToken), "")
    }

    private func restoreParagraphBreaks(in text: String, paragraphToken: String) -> String {
        let restored = text.replacingOccurrences(of: paragraphToken, with: "\n\n")
        return restored
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]*\n\n[ \t]*"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
