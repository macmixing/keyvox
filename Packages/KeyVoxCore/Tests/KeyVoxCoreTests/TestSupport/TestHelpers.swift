import Foundation
import XCTest
@testable import KeyVoxCore

func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyVoxCoreTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    return try body(root)
}

@MainActor
func waitForCondition(
    timeout: TimeInterval = 1.0,
    pollInterval: UInt64 = 20_000_000,
    _ condition: @escaping () -> Bool
) async throws {
    let start = Date()
    while !condition() {
        if Date().timeIntervalSince(start) > timeout {
            XCTFail("Timed out waiting for async condition")
            throw CancellationError()
        }
        try await Task.sleep(nanoseconds: pollInterval)
    }
}

@MainActor
final class FakeLexicon: PronunciationLexiconProviding {
    var pronunciations: [String: String]
    var commonWords: Set<String>

    init(pronunciations: [String: String] = [:], commonWords: Set<String> = []) {
        self.pronunciations = pronunciations
        self.commonWords = commonWords
    }

    func pronunciation(for normalizedWord: String) -> String? {
        pronunciations[normalizedWord]
    }

    func isCommonWord(_ normalizedWord: String) -> Bool {
        commonWords.contains(normalizedWord)
    }
}

final class FailingDirectoryFileManager: FileManager {
    var shouldFailCreateDirectory = false

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        if shouldFailCreateDirectory {
            throw NSError(domain: "FailingDirectoryFileManager", code: 42)
        }

        try super.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
}
