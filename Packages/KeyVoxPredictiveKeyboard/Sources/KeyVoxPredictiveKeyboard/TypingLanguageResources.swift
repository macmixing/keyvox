import Foundation

/// Where one typing language's bundled files are: its own folder in `PredictiveData`, and, for a
/// regional variant, the folder of the language whose dictionary, models, and swipe files it uses
/// where it has none of its own (`language.json`'s `sharedDataFolder`).
public struct TypingLanguageResources: Sendable {
    /// One folder in `PredictiveData`, with its name.
    private struct Folder: Sendable {
        let identifier: String
        let url: URL
    }

    private let predictiveData: URL
    private let own: Folder
    /// The folder whose data files the language uses where its own folder has none.
    private let shared: Folder?

    init(identifier: String, bundle: Bundle = KeyVoxPredictiveKeyboardResources.bundle) throws {
        guard let data = bundle.url(forResource: "PredictiveData", withExtension: nil),
              data.hasDirectoryPath else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData")
        }
        predictiveData = data
        own = try Self.folder(identifier, in: data)
        shared = nil
    }

    private init(predictiveData: URL, own: Folder, shared: Folder) {
        self.predictiveData = predictiveData
        self.own = own
        self.shared = shared
    }

    /// The same language using the data files of the folder `identifier` where its own folder
    /// has none.
    func sharingData(withFolder identifier: String) throws -> TypingLanguageResources {
        TypingLanguageResources(
            predictiveData: predictiveData,
            own: own,
            shared: try Self.folder(identifier, in: predictiveData)
        )
    }

    /// The language's own file named `name`, such as its `language.json` or one of its rule lists.
    func url(_ name: String) throws -> URL {
        let url = own.url.appendingPathComponent(name, isDirectory: false)
        guard Self.exists(url, isDirectory: false) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return url
    }

    /// The data file named `name`, such as `grammar_words.txt`: the language's own, or else the
    /// shared folder's.
    func dataURL(_ name: String) throws -> URL {
        guard let url = optionalDataURL(name) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return url
    }

    /// The data file named `name` when the language has one, its own or the shared folder's, such
    /// as a swipe model's optional decoder.
    func optionalDataURL(_ name: String) -> URL? {
        dataFolder(holding: name, isDirectory: false)?.url.appendingPathComponent(name, isDirectory: false)
    }

    /// The data folder named `name`, such as the dictionary: the language's own, or else the
    /// shared folder's.
    func dataDirectory(_ name: String) throws -> URL {
        guard let folder = dataFolder(holding: name, isDirectory: true) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return folder.url.appendingPathComponent(name, isDirectory: true)
    }

    /// The name of the folder `dataDirectory(name)` comes from, such as the language whose
    /// dictionary a variant uses.
    func dataIdentifier(ofDirectory name: String) throws -> String {
        guard let folder = dataFolder(holding: name, isDirectory: true) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return folder.identifier
    }

    private func dataFolder(holding name: String, isDirectory: Bool) -> Folder? {
        [own, shared].compactMap { $0 }.first { folder in
            Self.exists(folder.url.appendingPathComponent(name, isDirectory: isDirectory), isDirectory: isDirectory)
        }
    }

    private static func folder(_ identifier: String, in predictiveData: URL) throws -> Folder {
        let url = predictiveData.appendingPathComponent(identifier, isDirectory: true)
        guard exists(url, isDirectory: true) else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData/\(identifier)")
        }
        return Folder(identifier: identifier, url: url)
    }

    private static func exists(_ url: URL, isDirectory: Bool) -> Bool {
        var foundDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &foundDirectory)
            && foundDirectory.boolValue == isDirectory
    }
}
