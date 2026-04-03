import Foundation

enum PocketTTSChunkPlanner {
    private static let abbreviations: Set<String> = [
        "dr", "mr", "mrs", "ms", "prof", "sr", "jr", "st", "vs", "etc",
        "inc", "ltd", "co", "corp", "dept", "univ", "govt", "approx",
        "avg", "est", "gen", "gov", "hon", "sgt", "cpl", "pvt", "capt",
        "lt", "col", "maj", "cmdr", "adm", "rev", "sen", "rep",
    ]
    private static let hardBreakPattern = #"\n\s*\n+"#
    private static let softBreakPattern = #"\s*\n\s*"#
    private static let repeatedChevronPattern = #">\s*>\s*>+"#
    private static let urlPattern = #"https?://\S+"#

    static func normalize(_ text: String) -> (text: String, framesAfterEOS: Int) {
        var normalized = sanitize(text).trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        while let last = normalized.last, ",;:".contains(last) {
            normalized.removeLast()
        }
        normalized = normalized.trimmingCharacters(in: .whitespaces)

        if let firstCharacter = normalized.first, firstCharacter.isLetter {
            normalized = firstCharacter.uppercased() + normalized.dropFirst()
        }
        if let lastCharacter = normalized.last, !".!?".contains(lastCharacter) {
            normalized.append(".")
        }

        let wordCount = normalized.split(separator: " ").count
        if wordCount < PocketTTSConstants.shortTextWordThreshold {
            return (String(repeating: " ", count: 8) + normalized, PocketTTSConstants.shortTextPadFrames)
        }

        return (normalized, PocketTTSConstants.longTextExtraFrames)
    }

    static func chunk(_ text: String, tokenizer: SentencePieceTokenizer) -> [String] {
        let trimmed = sanitize(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if tokenizer.encode(trimmed).count <= PocketTTSConstants.maxTokensPerChunk {
            return [trimmed]
        }

        let paragraphPieces = splitParagraphs(in: trimmed)
        var sentencePieces: [String] = []

        for paragraph in paragraphPieces {
            let normalizedParagraph = paragraph
                .replacingOccurrences(of: softBreakPattern, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedParagraph.isEmpty else { continue }

            let sentences = splitSentences(in: normalizedParagraph)
            if sentences.isEmpty {
                sentencePieces.append(contentsOf: splitOversizedSentence(normalizedParagraph, tokenizer: tokenizer))
                continue
            }

            sentencePieces.append(contentsOf: sentences.flatMap { sentence in
                if tokenizer.encode(sentence).count <= PocketTTSConstants.maxTokensPerChunk {
                    return [sentence]
                }
                return splitOversizedSentence(sentence, tokenizer: tokenizer)
            })
        }

        var chunks: [String] = []
        var currentChunk = ""

        for piece in sentencePieces {
            let candidate = currentChunk.isEmpty ? piece : currentChunk + " " + piece
            if shouldAppend(
                piece,
                to: currentChunk,
                candidate: candidate,
                tokenizer: tokenizer
            ) {
                currentChunk = candidate
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = piece
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        return chunks.isEmpty ? [trimmed] : chunks
    }

    private static func shouldAppend(
        _ piece: String,
        to currentChunk: String,
        candidate: String,
        tokenizer: SentencePieceTokenizer
    ) -> Bool {
        guard !currentChunk.isEmpty else {
            return tokenizer.encode(candidate).count <= PocketTTSConstants.maxTokensPerChunk
        }

        guard tokenizer.encode(candidate).count <= PocketTTSConstants.maxTokensPerChunk else {
            return false
        }

        let currentSentenceCount = splitSentences(in: currentChunk).count
        let pieceSentenceCount = splitSentences(in: piece).count
        if currentSentenceCount == 0 || pieceSentenceCount == 0 {
            return true
        }

        let combinedSentenceCount = splitSentences(in: candidate).count
        if combinedSentenceCount >= currentSentenceCount + pieceSentenceCount {
            return true
        }

        return tokenizer.encode(candidate).count <= (PocketTTSConstants.maxTokensPerChunk - 8)
    }

    private static func splitOversizedSentence(_ sentence: String, tokenizer: SentencePieceTokenizer) -> [String] {
        var pieces: [String] = []
        var current = ""

        for clause in splitClauses(in: sentence) {
            let candidate = current.isEmpty ? clause : current + " " + clause
            if tokenizer.encode(candidate).count <= PocketTTSConstants.maxTokensPerChunk {
                current = candidate
                continue
            }

            if !current.isEmpty {
                pieces.append(current)
                current = ""
            }

            if tokenizer.encode(clause).count <= PocketTTSConstants.maxTokensPerChunk {
                current = clause
            } else {
                pieces.append(contentsOf: splitAtWordBoundaries(clause, tokenizer: tokenizer))
            }
        }

        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces.isEmpty ? [sentence] : pieces
    }

    private static func splitClauses(in text: String) -> [String] {
        let scalars = Array(text)
        var parts: [String] = []
        var current = ""

        for index in scalars.indices {
            let character = scalars[index]
            current.append(character)
            guard ",;:—".contains(character) else { continue }
            if character == "," {
                let previousIsDigit = index > 0 && scalars[scalars.index(before: index)].isNumber
                let nextIsDigit = index < scalars.index(before: scalars.endIndex) && scalars[scalars.index(after: index)].isNumber
                if previousIsDigit && nextIsDigit {
                    continue
                }
            }
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                parts.append(trimmed)
            }
            current = ""
        }

        let remainder = current.trimmingCharacters(in: .whitespaces)
        if !remainder.isEmpty {
            parts.append(remainder)
        }
        return parts
    }

    private static func splitAtWordBoundaries(_ text: String, tokenizer: SentencePieceTokenizer) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard words.count > 1 else { return [text] }

        var chunks: [String] = []
        var currentWords: [String] = []

        for word in words {
            let candidate = (currentWords + [word]).joined(separator: " ")
            if tokenizer.encode(candidate).count <= PocketTTSConstants.maxTokensPerChunk || currentWords.isEmpty {
                currentWords.append(word)
            } else {
                chunks.append(currentWords.joined(separator: " "))
                currentWords = [word]
            }
        }

        if !currentWords.isEmpty {
            chunks.append(currentWords.joined(separator: " "))
        }
        return chunks
    }

    private static func splitParagraphs(in text: String) -> [String] {
        let nsText = text as NSString
        let matches = regex(hardBreakPattern).matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        guard !matches.isEmpty else {
            return [text]
        }

        var paragraphs: [String] = []
        var currentLocation = 0

        for match in matches {
            let range = NSRange(location: currentLocation, length: match.range.location - currentLocation)
            let segment = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty {
                paragraphs.append(segment)
            }
            currentLocation = NSMaxRange(match.range)
        }

        let remainderRange = NSRange(location: currentLocation, length: nsText.length - currentLocation)
        let remainder = nsText.substring(with: remainderRange).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty {
            paragraphs.append(remainder)
        }

        return paragraphs
    }

    private static func splitSentences(in text: String) -> [String] {
        let characters = Array(text)
        var current = ""
        var sentences: [String] = []

        var index = 0
        while index < characters.count {
            let character = characters[index]
            current.append(character)
            guard ".!?".contains(character) else {
                index += 1
                continue
            }

            if character == "." {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                let stem = String(trimmed.dropLast())
                let lastWord = stem.split(separator: " ").last.map(String.init) ?? stem
                if abbreviations.contains(lastWord.lowercased()) {
                    index += 1
                    continue
                }
                if lastWord.count == 1, lastWord.first?.isUppercase == true {
                    index += 1
                    continue
                }
                if index + 1 < characters.count,
                   characters[index + 1].isNumber {
                    index += 1
                    continue
                }
                if stem.last?.isNumber == true,
                   index > 0,
                   characters[index - 1].isNumber {
                    index += 1
                    continue
                }
            }

            while index + 1 < characters.count {
                let nextCharacter = characters[index + 1]
                if "\"')]}".contains(nextCharacter) {
                    current.append(nextCharacter)
                    index += 1
                    continue
                }
                break
            }

            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                sentences.append(trimmed)
            }
            current = ""
            index += 1
        }

        let remainder = current.trimmingCharacters(in: .whitespaces)
        if !remainder.isEmpty {
            sentences.append(remainder)
        }
        return sentences
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    private static func sanitize(_ text: String) -> String {
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
            of: repeatedChevronPattern,
            with: ". ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: urlPattern,
            with: " link ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"[^A-Za-z0-9\s\.,!\?;:'"\(\)\[\]\/\-\n]"#,
            with: " ",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return sanitized
    }
}
