import Foundation

public enum DictionaryHintPromptBuilder {
    public static func prompt(
        for userEntries: [DictionaryEntry],
        maxEntries: Int = 200,
        maxChars: Int = 1200
    ) -> String {
        let candidates = userEntries
            .map(\.phrase)
            .filter { !$0.isEmpty }
            .suffix(maxEntries)

        guard !candidates.isEmpty else { return "" }

        var prompt = "Domain vocabulary: "
        var appendedCount = 0
        for phrase in candidates {
            let separator = prompt == "Domain vocabulary: " ? "" : ", "
            let chunk = separator + phrase
            if prompt.count + chunk.count > maxChars {
                break
            }
            prompt += chunk
            appendedCount += 1
        }

        return appendedCount == 0 ? "" : prompt
    }
}
