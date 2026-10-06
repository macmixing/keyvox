import Foundation

/// What the Apple keyboard baseline runner recorded: the text field contents after
/// each planned sentence was tapped out on the system keyboard.
struct AppleBaselineResults: Codable {
    struct Sentence: Codable {
        let text: String
    }

    let device: String
    let systemVersion: String
    let sentences: [Sentence]

    static func load(from path: String) throws -> AppleBaselineResults {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(AppleBaselineResults.self, from: data)
    }

    /// Lowercased words of a recorded sentence with surrounding punctuation removed.
    static func words(in text: String) -> [String] {
        text.replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: CharacterSet.letters.inverted).lowercased() }
            .filter { $0.isEmpty == false }
    }
}
