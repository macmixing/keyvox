import KeyVoxTypingSimulation

/// How a regression case's outcome differs from the recorded one, said by the word that came
/// out differently and the bar that changed.
enum TypingRegressionDifference {
    static func messages(
        language: String,
        caseNumber: Int,
        typingCase: TypingRegressionCase,
        expected: TypingRegressionOutcome,
        actual: TypingRegressionOutcome
    ) -> [String] {
        let name = "\(language) case \(caseNumber) (\"\(typingCase.intended.joined(separator: " "))\")"
        var messages: [String] = []
        let expectedWords = words(in: expected.text)
        let actualWords = words(in: actual.text)
        if let index = (0..<max(expectedWords.count, actualWords.count)).first(where: {
            expectedWords[safe: $0] != actualWords[safe: $0]
        }) {
            messages.append(
                "\(name): word \(index + 1) was \(quoted(expectedWords[safe: index])), "
                    + "now \(quoted(actualWords[safe: index])); "
                    + "text was \"\(expected.text)\", now \"\(actual.text)\""
            )
        } else if expected.text != actual.text {
            messages.append("\(name): text was \"\(expected.text)\", now \"\(actual.text)\"")
        }
        for (index, point) in typingCase.bars.enumerated()
        where expected.bars[safe: index] != actual.bars[safe: index] {
            let moment = point.letters == 0
                ? "before word \(point.word + 1)"
                : "after \(point.letters) letters of word \(point.word + 1)"
            messages.append(
                "\(name): bar \(moment) was \(listed(expected.bars[safe: index])), now \(listed(actual.bars[safe: index]))"
            )
        }
        return messages
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func quoted(_ word: String?) -> String {
        word.map { "\"\($0)\"" } ?? "nothing"
    }

    private static func listed(_ bar: TypingRegressionOutcome.Bar?) -> String {
        guard let bar else { return "nothing" }
        let slots = [bar.leading, bar.primary, bar.trailing].map { item in
            item.map { "\($0.kind) \"\($0.text)\"" } ?? "empty"
        }
        let emoji = bar.emoji.isEmpty ? "" : ", emoji " + bar.emoji.map(\.text).joined(separator: " ")
        return "[" + slots.joined(separator: " | ") + emoji + "]"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
