import Foundation

/// Finds emoji by the words that describe them, as the system emoji keyboard's search was seen
/// finding them (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): every word searched
/// for must start a word of the emoji's, in any order, so a word still being typed finds emoji
/// already; emoji every searched word names whole come first, then the rest, each in the order of
/// the search data, written by `Tools/KeyVoxEmojiData/write_emoji_search.py`.
public struct EmojiSearch: Sendable {
    /// Every emoji the data has words for, in the data's order.
    private let emoji: [String]
    /// Every word, sorted, so the words a searched word starts sit together.
    private let words: [String]
    /// The places in `emoji` of the emoji each word finds: those of `words[i]` run from
    /// `wordEmojiStarts[i]` up to `wordEmojiStarts[i + 1]`.
    private let wordEmoji: [UInt16]
    private let wordEmojiStarts: [Int]

    public static func bundled() throws -> EmojiSearch {
        try EmojiSearch(contentsOf: EmojiDataLocator().url(name: "emoji_search", extension: "txt"))
    }

    /// Reads search data of one line per emoji: the emoji and its words separated by spaces,
    /// split by a tab.
    public init(contentsOf url: URL) throws {
        var emoji: [String] = []
        var emojiByWord: [String: [UInt16]] = [:]
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() where line.isEmpty == false {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2, fields[0].isEmpty == false, fields[1].isEmpty == false,
                  emoji.count <= Int(UInt16.max) else {
                throw EmojiDataError.invalidSearch(line: index + 1)
            }
            let place = UInt16(emoji.count)
            emoji.append(String(fields[0]))
            for word in fields[1].split(separator: " ") {
                emojiByWord[String(word), default: []].append(place)
            }
        }
        guard emoji.isEmpty == false else {
            throw EmojiDataError.invalidSearch(line: lines.count)
        }
        let words = emojiByWord.keys.sorted()
        var wordEmoji: [UInt16] = []
        var wordEmojiStarts: [Int] = []
        for word in words {
            wordEmojiStarts.append(wordEmoji.count)
            wordEmoji.append(contentsOf: emojiByWord[word] ?? [])
        }
        wordEmojiStarts.append(wordEmoji.count)
        self.emoji = emoji
        self.words = words
        self.wordEmoji = wordEmoji
        self.wordEmojiStarts = wordEmojiStarts
    }

    /// The emoji `search` finds, in order, with `first` ahead of them: the suggestion bar's emoji
    /// for a search of one word (`EmojiPredictions`), so a search finds first what the bar offers.
    public func results(for search: String, first: [String]) -> [String] {
        first + results(for: search).filter { first.contains($0) == false }
    }

    /// The emoji `search` finds, in order; none for a search without words.
    public func results(for search: String) -> [String] {
        let searchedWords = Self.words(in: search)
        guard searchedWords.isEmpty == false else { return [] }
        var found: Set<UInt16>?
        var foundWhole: Set<UInt16>?
        for searchedWord in searchedWords {
            var started = Set<UInt16>()
            var whole = Set<UInt16>()
            var index = firstWord(notBefore: searchedWord)
            while index < words.count, words[index].hasPrefix(searchedWord) {
                let finds = wordEmoji[wordEmojiStarts[index]..<wordEmojiStarts[index + 1]]
                started.formUnion(finds)
                if words[index] == searchedWord {
                    whole.formUnion(finds)
                }
                index += 1
            }
            found = found.map { $0.intersection(started) } ?? started
            foundWhole = foundWhole.map { $0.intersection(whole) } ?? whole
        }
        let places = (found ?? []).sorted()
        let wholePlaces = foundWhole ?? []
        return (places.filter { wholePlaces.contains($0) } + places.filter { wholePlaces.contains($0) == false })
            .map { emoji[Int($0)] }
    }

    /// The words of `text` as the search data has them: runs of letters and digits, decomposed
    /// for compatibility, without nonspacing marks, lowercased, so neither case nor accents
    /// keep a search from finding a word.
    static func words(in text: String) -> [String] {
        let folded = text.decomposedStringWithCompatibilityMapping.unicodeScalars
            .filter { $0.properties.generalCategory != .nonspacingMark }
        var words: [String] = []
        var word = String.UnicodeScalarView()
        for scalar in String(String.UnicodeScalarView(folded)).lowercased().unicodeScalars {
            if isWordScalar(scalar) {
                word.append(scalar)
            } else if word.isEmpty == false {
                words.append(String(word))
                word = String.UnicodeScalarView()
            }
        }
        if word.isEmpty == false {
            words.append(String(word))
        }
        return words
    }

    private static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }

    /// The place in `words` of the first word not sorted before `word`.
    private func firstWord(notBefore word: String) -> Int {
        var low = 0
        var high = words.count
        while low < high {
            let middle = (low + high) / 2
            if words[middle] < word {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }
}
