import Foundation
import NaturalLanguage

struct WhisperSegmentTextAssembler: Sendable {
    private let pronunciationLookup: PronunciationLookup

    init(pronunciationLookup: PronunciationLookup) {
        self.pronunciationLookup = pronunciationLookup
    }

    func assemble(
        _ segmentTexts: [String],
        normalizesContinuationCasing: Bool
    ) async -> String {
        let punctuationNormalizer = TerminalPunctuationNormalizer()
        var assembled = ""

        for rawSegmentText in segmentTexts {
            let segmentText = normalizeWhitespace(rawSegmentText)
            guard !segmentText.isEmpty else { continue }

            let normalizedSegmentText: String
            if normalizesContinuationCasing,
               !assembled.isEmpty,
               !punctuationNormalizer.hasTerminalSentencePunctuation(assembled) {
                normalizedSegmentText = normalizeContinuationStart(
                    segmentText,
                    after: assembled
                )
            } else {
                normalizedSegmentText = segmentText
            }

            if !assembled.isEmpty {
                assembled += " "
            }
            assembled += normalizedSegmentText
        }

        return assembled
    }

    private func normalizeContinuationStart(
        _ segmentText: String,
        after precedingText: String
    ) -> String {
        let combinedText = "\(precedingText) \(segmentText)"
        let segmentStart = combinedText.index(combinedText.endIndex, offsetBy: -segmentText.count)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = combinedText

        var candidate: (range: Range<String.Index>, tag: NLTag?)?
        tagger.enumerateTags(
            in: segmentStart..<combinedText.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            candidate = (range, tag)
            return false
        }

        guard let candidate, candidate.tag == .otherWord else { return segmentText }

        let token = String(combinedText[candidate.range])
        guard token.count > 1,
              token.first?.isUppercase == true,
              token.dropFirst().allSatisfy({ !$0.isLetter || $0.isLowercase }) else {
            return segmentText
        }

        let normalizedToken = DictionaryTextNormalization.normalizedToken(token)
        guard pronunciationLookup.pronunciation(for: normalizedToken) != nil else {
            return segmentText
        }

        let lowerOffset = combinedText.distance(from: segmentStart, to: candidate.range.lowerBound)
        let upperOffset = combinedText.distance(from: segmentStart, to: candidate.range.upperBound)
        let localLowerBound = segmentText.index(segmentText.startIndex, offsetBy: lowerOffset)
        let localUpperBound = segmentText.index(segmentText.startIndex, offsetBy: upperOffset)

        var normalized = segmentText
        normalized.replaceSubrange(localLowerBound..<localUpperBound, with: token.lowercased())
        return normalized
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
