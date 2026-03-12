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
        if fileManager.fileExists(atPath: updatesURL.path) {
            try? fileManager.removeItem(at: updatesURL)
        }
        cleanupBackupBundles()
    }

    private func cleanupBackupBundles(bundleURL: URL = Bundle.main.bundleURL) {
        let parentURL = bundleURL.deletingLastPathComponent()
        let backupPrefix = "\(bundleURL.lastPathComponent).backup."

        guard let contents = try? fileManager.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for candidate in contents where candidate.lastPathComponent.hasPrefix(backupPrefix) {
            try? fileManager.removeItem(at: candidate)
        }
    }
}
