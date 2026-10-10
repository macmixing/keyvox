import Foundation

/// Keeps a `TypingMemory` in a JSON file at a location the host chooses, together with the
/// reset generation it was saved under. A host counts its resets in a place every process that
/// shares the file can read; a file saved under an earlier generation is out of date, as when
/// the user reset what the keyboard learned while a keyboard still held the old memory, and
/// restores nothing and is never written over by that memory.
public struct TypingMemoryFile: Sendable {
    private struct Contents: Codable {
        let resetGeneration: Int
        let memory: TypingMemory.Saved
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The memory saved under `resetGeneration`, or an empty one when there is none.
    public func load(resetGeneration: Int) -> TypingMemory.Saved {
        guard let data = try? Data(contentsOf: url),
              let contents = try? JSONDecoder().decode(Contents.self, from: data),
              contents.resetGeneration == resetGeneration else {
            return TypingMemory.Saved()
        }
        return contents.memory
    }

    public func save(_ memory: TypingMemory.Saved, resetGeneration: Int) throws {
        let data = try JSONEncoder().encode(Contents(resetGeneration: resetGeneration, memory: memory))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
