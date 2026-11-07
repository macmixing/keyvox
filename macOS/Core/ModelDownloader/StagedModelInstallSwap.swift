import Foundation

/// Swaps a fully staged model install into place while keeping the install it
/// replaces aside until the new one is confirmed ready.
nonisolated struct StagedModelInstallSwap {
    let fileManager: FileManager

    func install(stagedRootURL: URL, installRootURL: URL, previousRootURL: URL) throws {
        try removeItemIfPresent(at: previousRootURL)
        try fileManager.createDirectory(
            at: installRootURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: previousRootURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: installRootURL.path) {
            try fileManager.moveItem(at: installRootURL, to: previousRootURL)
        }

        do {
            try fileManager.moveItem(at: stagedRootURL, to: installRootURL)
        } catch {
            try? restorePrevious(installRootURL: installRootURL, previousRootURL: previousRootURL)
            throw error
        }
    }

    func restorePrevious(installRootURL: URL, previousRootURL: URL) throws {
        try removeItemIfPresent(at: installRootURL)
        guard fileManager.fileExists(atPath: previousRootURL.path) else { return }
        try fileManager.moveItem(at: previousRootURL, to: installRootURL)
    }

    func discardPrevious(previousRootURL: URL) {
        try? removeItemIfPresent(at: previousRootURL)
    }

    private func removeItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
