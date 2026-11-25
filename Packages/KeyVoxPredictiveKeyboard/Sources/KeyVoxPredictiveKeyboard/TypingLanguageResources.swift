import Foundation

/// Where one typing language's bundled files are: its own folder in `PredictiveData`.
public struct TypingLanguageResources: Sendable {
    private let directory: URL

    init(identifier: String, bundle: Bundle = KeyVoxPredictiveKeyboardResources.bundle) throws {
        guard let data = bundle.url(forResource: "PredictiveData", withExtension: nil),
              data.hasDirectoryPath else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData")
        }
        let directory = data.appendingPathComponent(identifier, isDirectory: true)
        guard Self.exists(directory, isDirectory: true) else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData/\(identifier)")
        }
        self.directory = directory
    }

    /// The language's file named `name`, such as `grammar_words.txt`.
    func url(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: false)
        guard Self.exists(url, isDirectory: false) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return url
    }

    /// The language's file named `name` when it has one, such as a swipe model's optional decoder.
    func optionalURL(_ name: String) -> URL? {
        let url = directory.appendingPathComponent(name, isDirectory: false)
        return Self.exists(url, isDirectory: false) ? url : nil
    }

    /// The language's folder named `name`, such as its dictionary.
    func directory(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        guard Self.exists(url, isDirectory: true) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return url
    }

    private static func exists(_ url: URL, isDirectory: Bool) -> Bool {
        var foundDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &foundDirectory)
            && foundDirectory.boolValue == isDirectory
    }
}
