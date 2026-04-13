import Foundation
import AppKit

struct AppUpdateResumeAfterApplicationsMoveContext {
    let preferredDisplayKey: String?
}

struct AppUpdateApplicationsPrereflight {
    private let fileManager: FileManager
    private let defaults: UserDefaults

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    func requiresApplicationsInstall(bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        let standardizedPath = bundleURL.standardizedFileURL.path
        return !standardizedPath.hasPrefix("/Applications/")
    }

    func destinationURL(for bundleURL: URL = Bundle.main.bundleURL) -> URL {
        URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent(bundleURL.lastPathComponent, isDirectory: true)
    }

    func stageResumeAfterApplicationsMove(preferredDisplayKey: String?) {
        defaults.set(true, forKey: UserDefaultsKeys.App.resumeUpdaterAfterApplicationsMove)
        if let preferredDisplayKey {
            defaults.set(preferredDisplayKey, forKey: UserDefaultsKeys.App.resumeUpdaterPreferredDisplayKey)
        } else {
            defaults.removeObject(forKey: UserDefaultsKeys.App.resumeUpdaterPreferredDisplayKey)
        }
    }

    func stageResumeAfterApplicationsMove() {
        stageResumeAfterApplicationsMove(preferredDisplayKey: nil)
    }

    func consumeResumeAfterApplicationsMoveContext() -> AppUpdateResumeAfterApplicationsMoveContext? {
        let shouldResume = defaults.bool(forKey: UserDefaultsKeys.App.resumeUpdaterAfterApplicationsMove)
        let preferredDisplayKey = defaults.string(forKey: UserDefaultsKeys.App.resumeUpdaterPreferredDisplayKey)
        if shouldResume {
            defaults.removeObject(forKey: UserDefaultsKeys.App.resumeUpdaterAfterApplicationsMove)
            defaults.removeObject(forKey: UserDefaultsKeys.App.resumeUpdaterPreferredDisplayKey)
            return AppUpdateResumeAfterApplicationsMoveContext(preferredDisplayKey: preferredDisplayKey)
        }
        return nil
    }

    func consumeResumeAfterApplicationsMove() -> Bool {
        consumeResumeAfterApplicationsMoveContext() != nil
    }

    func moveCurrentAppToApplications(bundleURL: URL = Bundle.main.bundleURL) throws -> URL {
        let sourceURL = bundleURL.standardizedFileURL
        let destinationURL = destinationURL(for: sourceURL)
        let stagingURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.deletingPathExtension().lastPathComponent)-staged-\(UUID().uuidString).app")

        if sourceURL == destinationURL {
            return destinationURL
        }

        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }
        try fileManager.copyItem(at: sourceURL, to: stagingURL)

        if fileManager.fileExists(atPath: destinationURL.path) {
            var resultingURL: NSURL?
            try fileManager.replaceItem(
                at: destinationURL,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: &resultingURL
            )
            return (resultingURL as URL?) ?? destinationURL
        }

        try fileManager.moveItem(at: stagingURL, to: destinationURL)
        return destinationURL
    }
}
