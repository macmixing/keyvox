import Foundation
import KeyVoxLinguistics

struct WhisperSegmentTextAssembler: Sendable {
    private let pronunciationLookup: PronunciationLookup
    private let linguisticAnalyzer: any LinguisticAnalyzing

    init(
        pronunciationLookup: PronunciationLookup,
        linguisticAnalyzer: any LinguisticAnalyzing = TextLinguistics.provider
    ) {
        self.pronunciationLookup = pronunciationLookup
        self.linguisticAnalyzer = linguisticAnalyzer
    }

    func assemble(
        _ segmentTexts: [String],
        after precedingText: String = "",
        normalizesContinuationCasing: Bool
    ) async -> String {
        let punctuationNormalizer = TerminalPunctuationNormalizer()
        var assembled = ""

        for rawSegmentText in segmentTexts {
            let segmentText = normalizeWhitespace(rawSegmentText)
            guard !segmentText.isEmpty else { continue }

            let normalizedSegmentText: String
            let continuationContext = assembled.isEmpty ? precedingText : assembled
            if normalizesContinuationCasing,
               !continuationContext.isEmpty,
               !punctuationNormalizer.hasTerminalSentencePunctuation(continuationContext) {
                normalizedSegmentText = normalizeContinuationStart(
                    segmentText,
                    after: continuationContext
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
        let analysis = linguisticAnalyzer.analyze(
            combinedText,
            range: NSRange(segmentStart..<combinedText.endIndex, in: combinedText),
            languageCode: nil,
            features: [.names],
            grouping: .words
        )
        guard let candidate = analysis.tokens.first,
              candidate.identity == .ordinaryWord,
              let candidateRange = Range(candidate.range, in: combinedText) else { return segmentText }

        let token = String(combinedText[candidateRange])
        guard token.count > 1,
              token.first?.isUppercase == true,
              token.dropFirst().allSatisfy({ !$0.isLetter || $0.isLowercase }) else {
            return segmentText
        }

        let normalizedToken = DictionaryTextNormalization.normalizedToken(token)
        guard pronunciationLookup.pronunciation(for: normalizedToken) != nil else {
            return segmentText
        }

        let lowerOffset = combinedText.distance(from: segmentStart, to: candidateRange.lowerBound)
        let upperOffset = combinedText.distance(from: segmentStart, to: candidateRange.upperBound)
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
