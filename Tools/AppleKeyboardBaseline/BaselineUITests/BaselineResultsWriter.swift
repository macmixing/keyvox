import Foundation

/// Writes the recorded sentences in the format `KeyVoxTypingHarness compare` reads.
/// Rewritten after every sentence so an interrupted run keeps its progress.
struct BaselineResultsWriter {
    private struct Results: Encodable {
        struct Sentence: Encodable {
            let text: String
        }

        let device: String
        let systemVersion: String
        let keyboard: String
        let sentences: [Sentence]
    }

    let path: String
    let device: String
    let systemVersion: String
    let keyboard: String

    func write(_ texts: [String]) throws {
        let results = Results(
            device: device,
            systemVersion: systemVersion,
            keyboard: keyboard,
            sentences: texts.map(Results.Sentence.init(text:))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
