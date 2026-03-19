import Foundation
import XCTest
@testable import KeyVox
import KeyVoxCore

@MainActor
final class RecordingPromptPresenter: UpdatePromptPresenting {
    private(set) var prompts: [UpdatePrompt] = []

    func show(prompt: UpdatePrompt) {
        prompts.append(prompt)
    }

    func reset() {
        prompts.removeAll()
    }
}

final class MutableNow {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func advance(by interval: TimeInterval) {
        value = value.addingTimeInterval(interval)
    }
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyVoxTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    return try body(root)
}

func fixtureURL(named name: String, ext: String = "json", file: StaticString = #filePath) -> URL {
    let sourceURL = URL(fileURLWithPath: "\(file)")
    return sourceURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("Updates", isDirectory: true)
        .appendingPathComponent("\(name).\(ext)")
}

func loadFixtureData(named name: String) throws -> Data {
    try Data(contentsOf: fixtureURL(named: name))
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
