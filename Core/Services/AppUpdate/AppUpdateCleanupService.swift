import Foundation

struct AppUpdateCleanupService {
    private let fileManager: FileManager
    private let paths: AppUpdatePaths

    init(
        fileManager: FileManager = .default,
        paths: AppUpdatePaths = AppUpdatePaths()
    ) {
        self.fileManager = fileManager
        self.paths = paths
    }

    func cleanupStaleArtifacts() {
        let updatesURL = paths.updatesDirectoryURL
        guard fileManager.fileExists(atPath: updatesURL.path) else { return }
        try? fileManager.removeItem(at: updatesURL)
    }
}
