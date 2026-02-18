import Foundation

struct ListPatternTrailingSplitter {
    func splitLastItemAndTrailing(_ raw: String) -> (itemText: String, trailingText: String) {
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
