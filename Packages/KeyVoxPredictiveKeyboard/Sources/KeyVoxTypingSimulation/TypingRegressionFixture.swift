import Foundation

/// Where a typing language's regression check is kept, and how its files are written: in a
/// folder named by the language's identifier, `cases.jsonl` holds its cases and
/// `expected.jsonl` what typing each one gave when it was last recorded, one JSON object a line,
/// line for line, so a change to one case's outcome is a change to one line.
public enum TypingRegressionFixture {
    public static let casesFileName = "cases.jsonl"
    public static let expectedFileName = "expected.jsonl"

    /// The identifiers of the languages with cases in `folder`, ordered.
    public static func languages(in folder: URL, fileManager: FileManager = .default) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: folder.path)
            .filter { fileManager.fileExists(atPath: casesURL(in: folder, language: $0).path) }
            .sorted()
    }

    public static func casesURL(in folder: URL, language: String) -> URL {
        folder.appendingPathComponent(language, isDirectory: true).appendingPathComponent(casesFileName)
    }

    public static func expectedURL(in folder: URL, language: String) -> URL {
        folder.appendingPathComponent(language, isDirectory: true).appendingPathComponent(expectedFileName)
    }

    /// Every line of the JSON Lines file at `url`, decoded.
    public static func read<Value: Decodable>(_: Value.Type, from url: URL) throws -> [Value] {
        let decoder = JSONDecoder()
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { try decoder.decode(Value.self, from: Data($0.utf8)) }
    }

    /// Writes `values` to `url` as JSON Lines, keys sorted, creating its folder.
    public static func write<Value: Encodable>(_ values: [Value], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let lines = try values.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
