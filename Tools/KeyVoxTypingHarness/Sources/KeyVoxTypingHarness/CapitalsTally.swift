/// How many words a typed sentence writes with the capitals its corpus writes them with: of the
/// words after the sentence's first that come out right, those the corpus capitalizes that kept
/// their capitals, and those it writes in lowercase that gained one. The first word is left out,
/// as the harness types no shift and a sentence's start is the keyboard's shift, not its words.
struct CapitalsTally {
    private(set) var capitalized = 0
    private(set) var keptCapitals = 0
    private(set) var lowercase = 0
    private(set) var addedCapitals = 0

    /// - Parameters:
    ///   - written: The sentence's words as the corpus writes them.
    ///   - intended: The same words in lowercase.
    ///   - typed: What typing the sentence produced.
    mutating func record(written: [String], intended: [String], typed: String) {
        let produced = AppleBaselineResults.writtenWords(in: typed)
        let aligned = WordAlignment.alignedIndices(intended: intended, produced: produced.map { $0.lowercased() })
        for index in written.indices.dropFirst() {
            guard let word = aligned[index].map({ produced[$0] }), word.lowercased() == intended[index] else {
                continue
            }
            if written[index] != written[index].lowercased() {
                capitalized += 1
                keptCapitals += word == written[index] ? 1 : 0
            } else {
                lowercase += 1
                addedCapitals += word == written[index] ? 0 : 1
            }
        }
    }
}
