/// Text to hold a delete key over: sentences of made-up words whose lengths cycle from one to
/// nine letters, some with an apostrophe or a comma, so each deleted run shows whether a
/// keyboard took a letter, a word, or more.
enum DeletionSampleText {
    static func make(words count: Int = 120) -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        var text = ""
        for index in 0..<count {
            let length = 1 + (index * 4) % 9
            var word = String((0..<length).map { letters[(index * 3 + $0) % letters.count] })
            if index % 11 == 5 {
                word += "'s"
            }
            if index % 8 == 7 {
                word += "."
            } else if index % 13 == 6 {
                word += ","
            }
            text += index == 0 ? word : " " + word
        }
        return text
    }

    /// Words of 26 letters each, so a held delete crosses no word boundary for a while.
    static func longWords(count: Int = 12) -> String {
        (0..<count).map { _ in "abcdefghijklmnopqrstuvwxyz" }.joined(separator: " ")
    }

    /// Short sentences, each on its own line.
    static func lines(count: Int = 30) -> String {
        (0..<count).map { index in make(words: 4 + index % 3) }.joined(separator: "\n")
    }
}
