import Foundation

struct AppUpdatePaths {
    private let fileManager: FileManager
    private let rootDirectory: URL

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.rootDirectory = appSupport
                .appendingPathComponent("KeyVox", isDirectory: true)
                .appendingPathComponent("Updates", isDirectory: true)
        }
    }

    var updatesDirectoryURL: URL {
        rootDirectory
    }

    func releaseDirectoryURL(for version: String) -> URL {
        updatesDirectoryURL.appendingPathComponent(version, isDirectory: true)
    }

    func zipURL(for version: String, assetName: String) -> URL {
        releaseDirectoryURL(for: version).appendingPathComponent(assetName)
    }

    func extractedDirectoryURL(for version: String) -> URL {
        releaseDirectoryURL(for: version).appendingPathComponent("extracted", isDirectory: true)
    }

    func createReleaseDirectoryIfNeeded(for version: String) throws {
        try fileManager.createDirectory(at: releaseDirectoryURL(for: version), withIntermediateDirectories: true)
    }
}
