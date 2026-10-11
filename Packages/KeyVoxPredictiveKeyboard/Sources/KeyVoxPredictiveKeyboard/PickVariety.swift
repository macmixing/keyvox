import Foundation

/// While the user picks the bar's words in a row, which of the about equally likely next words
/// leads depends on the words picked so far, so picking from different starts writes different
/// text instead of the same likeliest phrases every time. A word much likelier than the others
/// keeps its place. The order holds while the run of picks lasts and changes from one run to the
/// next.
struct PickVariety {
    /// How much less likely than the likeliest word a word may be and still count as about
    /// equally likely, as a natural log: half as likely.
    static let equallyLikelyLogMargin = log(2.0)

    private let pickedWords: [String]
    private let pickRun: Int

    /// - Parameters:
    ///   - pickedWords: The words picked in a row, newest first.
    ///   - pickRun: The number drawn when the run of picks started.
    init(pickedWords: [String], pickRun: Int) {
        self.pickedWords = pickedWords.map(PersonalVocabulary.key)
        self.pickRun = pickRun
    }

    /// `ranked`, best first, with the about equally likely words at the top in an order the picked
    /// words and their run decide.
    func ordering(_ ranked: [SuggestionCandidateRanker.RankedWord]) -> [String] {
        guard pickedWords.isEmpty == false, let best = ranked.first?.score else { return ranked.map(\.word) }
        let equallyLikely = ranked.prefix { best - $0.score <= Self.equallyLikelyLogMargin }.map(\.word)
        let varied = equallyLikely.sorted { place(of: $0) < place(of: $1) }
        return varied + ranked.dropFirst(equallyLikely.count).map(\.word)
    }

    private func place(of word: String) -> Int {
        var hasher = Hasher()
        hasher.combine(pickRun)
        hasher.combine(pickedWords)
        hasher.combine(PersonalVocabulary.key(word))
        return hasher.finalize()
    }
}
