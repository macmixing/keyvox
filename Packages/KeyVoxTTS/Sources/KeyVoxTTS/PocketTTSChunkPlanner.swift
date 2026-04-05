import Foundation
import NaturalLanguage

enum PocketTTSChunkPlanner {
    private static let hardBreakPattern = #"\n\s*\n+"#
    private static let softBreakPattern = #"\s*\n\s*"#

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

    static func chunk(_ text: String, tokenizer: SentencePieceTokenizer, fastModeEnabled: Bool = false) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let rawParagraphs = splitParagraphs(in: trimmed)
        let sanitizedParagraphs = rawParagraphs.map { sanitize($0) }
        let sanitizedText = sanitizedParagraphs.joined(separator: " ")
        
        let chunkTokenLimit = maxTokensPerChunk(for: sanitizedText, tokenizer: tokenizer)
        if tokenizer.encode(sanitizedText).count <= chunkTokenLimit {
            return [sanitizedText]
        }

        var sentencePieces: [String] = []

        for paragraph in sanitizedParagraphs {
            let normalizedParagraph = paragraph
                .replacingOccurrences(of: softBreakPattern, with: " ", options: String.CompareOptions.regularExpression)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !normalizedParagraph.isEmpty else { continue }

            let sentences = splitSentences(in: normalizedParagraph)
            if sentences.isEmpty {
                sentencePieces.append(contentsOf: splitOversizedSentence(normalizedParagraph, tokenizer: tokenizer, chunkTokenLimit: chunkTokenLimit))
                continue
            }

            sentencePieces.append(contentsOf: sentences.flatMap { sentence in
                if tokenizer.encode(sentence).count <= chunkTokenLimit {
                    return [sentence]
                }
                return splitOversizedSentence(sentence, tokenizer: tokenizer, chunkTokenLimit: chunkTokenLimit)
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
                tokenizer: tokenizer,
                chunkTokenLimit: chunkTokenLimit
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

        let finalizedChunks = chunks.isEmpty ? [sanitizedText] : chunks
        guard fastModeEnabled, let initialChunk = finalizedChunks.first else {
            return finalizedChunks
        }

        let fastModeInitialChunks = rechunk(
            initialChunk,
            tokenizer: tokenizer,
            chunkTokenLimit: PocketTTSConstants.fastModeInitialMaxTokensPerChunk
        )
        guard fastModeInitialChunks.isEmpty == false else {
            return finalizedChunks
        }

        return fastModeInitialChunks + finalizedChunks.dropFirst()
    }

    private static func rechunk(
        _ text: String,
        tokenizer: SentencePieceTokenizer,
        chunkTokenLimit: Int
    ) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }
        guard tokenizer.encode(trimmed).count > chunkTokenLimit else { return [trimmed] }

        let sentences = splitSentences(in: trimmed)
        let pieces: [String]
        if sentences.isEmpty {
            pieces = splitOversizedSentence(trimmed, tokenizer: tokenizer, chunkTokenLimit: chunkTokenLimit)
        } else {
            pieces = sentences.flatMap { sentence in
                if tokenizer.encode(sentence).count <= chunkTokenLimit {
                    return [sentence]
                }
                return splitOversizedSentence(sentence, tokenizer: tokenizer, chunkTokenLimit: chunkTokenLimit)
            }
        }

        var chunks: [String] = []
        var currentChunk = ""

        for piece in pieces {
            let candidate = currentChunk.isEmpty ? piece : currentChunk + " " + piece
            if shouldAppend(
                piece,
                to: currentChunk,
                candidate: candidate,
                tokenizer: tokenizer,
                chunkTokenLimit: chunkTokenLimit
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
        tokenizer: SentencePieceTokenizer,
        chunkTokenLimit: Int
    ) -> Bool {
        guard !currentChunk.isEmpty else {
            return tokenizer.encode(candidate).count <= chunkTokenLimit
        }

        guard tokenizer.encode(candidate).count <= chunkTokenLimit else {
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

        return tokenizer.encode(candidate).count <= (chunkTokenLimit - 8)
    }

    private static func splitOversizedSentence(
        _ sentence: String,
        tokenizer: SentencePieceTokenizer,
        chunkTokenLimit: Int
    ) -> [String] {
        var pieces: [String] = []
        var current = ""

        for clause in splitClauses(in: sentence) {
            let candidate = current.isEmpty ? clause : current + " " + clause
            if tokenizer.encode(candidate).count <= chunkTokenLimit {
                current = candidate
                continue
            }

            if !current.isEmpty {
                pieces.append(current)
                current = ""
            }

            if tokenizer.encode(clause).count <= chunkTokenLimit {
                current = clause
            } else {
                pieces.append(contentsOf: splitAtWordBoundaries(clause, tokenizer: tokenizer, chunkTokenLimit: chunkTokenLimit))
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

    private static func splitAtWordBoundaries(
        _ text: String,
        tokenizer: SentencePieceTokenizer,
        chunkTokenLimit: Int
    ) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard words.count > 1 else {
            let tokenCount = tokenizer.encode(text).count
            if tokenCount <= chunkTokenLimit {
                return [text]
            }
            
            var chunks: [String] = []
            var currentText = ""
            for char in text {
                let candidate = currentText + String(char)
                if tokenizer.encode(candidate).count <= chunkTokenLimit {
                    currentText = candidate
                } else {
                    if !currentText.isEmpty {
                        chunks.append(currentText)
                    }
                    currentText = String(char)
                }
            }
            if !currentText.isEmpty {
                chunks.append(currentText)
            }
            return chunks.isEmpty ? [text] : chunks
        }

        var chunks: [String] = []
        var currentWords: [String] = []

        for word in words {
            let candidate = (currentWords + [word]).joined(separator: " ")
            if tokenizer.encode(candidate).count <= chunkTokenLimit || currentWords.isEmpty {
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

    private static func maxTokensPerChunk(
        for text: String,
        tokenizer: SentencePieceTokenizer
    ) -> Int {
        let totalTokenCount = tokenizer.encode(text).count

        switch totalTokenCount {
        case (PocketTTSConstants.ultraLongFormTokenThreshold + 1)...:
            return PocketTTSConstants.ultraLongFormMaxTokensPerChunk
        case (PocketTTSConstants.longFormTokenThreshold + 1)...:
            return PocketTTSConstants.longFormMaxTokensPerChunk
        case (PocketTTSConstants.mediumFormTokenThreshold + 1)...:
            return PocketTTSConstants.mediumFormMaxTokensPerChunk
        default:
            return PocketTTSConstants.maxTokensPerChunk
        }
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
                if shouldSuppressSentenceBoundary(for: lastWord, in: stem) {
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

    private static func shouldSuppressSentenceBoundary(for word: String, in context: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = context
        
        let range = (context as NSString).range(of: word, options: .backwards)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: context) else { return false }
        
        let stringIndex = swiftRange.lowerBound
        
        let (tag, _) = tagger.tag(at: stringIndex, unit: .word, scheme: .lexicalClass)
        if let tag = tag {
            if tag == .determiner || tag == .preposition {
                return false
            }
        }
        
        let (nameTag, _) = tagger.tag(at: stringIndex, unit: .word, scheme: .nameType)
        if let nameTag = nameTag {
            if nameTag == .personalName || nameTag == .organizationName {
                let words = context.split(separator: " ")
                if words.count >= 2 {
                    let secondToLast = words.dropLast().last.map(String.init) ?? ""
                    if secondToLast.first?.isUppercase == true {
                        return true
                    }
                }
            }
        }
        
        let lowercased = word.lowercased()
        let commonAbbreviations: Set<String> = ["mr", "mrs", "ms", "dr", "st", "jr", "sr", "vs", "etc"]
        
        if commonAbbreviations.contains(lowercased) {
            return true
        }
        
        if word.uppercased() == word && word.count <= 4 {
            return true
        }
        
        return false
    }

    private static func sanitize(_ text: String) -> String {
        PocketTTSTextNormalizer.sanitize(text)
    }
}
