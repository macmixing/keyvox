import Foundation

enum StyleRewritePromptLeakGuard {
    static func fallbackIfNeeded(
        request: TextTransformRequest,
        result: TextTransformResult,
        processingMode: String
    ) -> TextTransformResult {
        guard containsPromptLeak(output: result.finalText, request: request) else {
            return result
        }

        return TextTransformResult(
            originalText: request.baseText,
            finalText: request.baseText,
            styleIdentifier: request.styleIdentifier,
            duration: result.duration,
            chunkCount: result.chunkCount,
            applied: false,
            chunkTimings: result.chunkTimings,
            errors: result.errors + [
                TextTransformErrorSummary(
                    chunkIndex: nil,
                    message: "promptLeakDetected",
                    errorCode: .promptLeakDetected
                )
            ],
            processingMode: processingMode
        )
    }

    static func containsPromptLeak(output: String, request: TextTransformRequest) -> Bool {
        let normalizedOutput = normalized(output)
        guard !normalizedOutput.isEmpty else { return false }

        return leakedPhrases(for: request).contains { phrase in
            normalizedOutput.contains(phrase)
        }
    }

    private static func leakedPhrases(for request: TextTransformRequest) -> [String] {
        [request.instructions, request.promptPrefix, request.promptSuffix]
            .flatMap(significantPhrases)
    }

    private static func significantPhrases(in text: String) -> [String] {
        let words = normalizedWords(in: text)
        guard words.count >= 6 else { return [] }

        var phrases: [String] = []
        for windowSize in [10, 8, 6] {
            guard words.count >= windowSize else { continue }
            for startIndex in 0...(words.count - windowSize) {
                let phrase = words[startIndex..<(startIndex + windowSize)].joined(separator: " ")
                phrases.append(phrase)
            }
        }
        return phrases
    }

    private static func normalized(_ text: String) -> String {
        normalizedWords(in: text).joined(separator: " ")
    }

    private static func normalizedWords(in text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}
