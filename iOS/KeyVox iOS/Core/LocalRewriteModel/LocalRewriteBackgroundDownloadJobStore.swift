import Foundation

struct LocalRewriteBackgroundDownloadJobStore {
    let fileManager: FileManager
    let jobURLProvider: () -> URL?

    func load() -> LocalRewriteBackgroundDownloadJob? {
        guard let jobURL = jobURLProvider(),
              fileManager.fileExists(atPath: jobURL.path),
              let data = try? Data(contentsOf: jobURL) else {
            return nil
        }
        return try? JSONDecoder().decode(LocalRewriteBackgroundDownloadJob.self, from: data)
    }

    func save(_ job: LocalRewriteBackgroundDownloadJob) throws {
        guard let jobURL = jobURLProvider() else {
            throw LocalRewriteModelInstallError.appGroupUnavailable
        }
        try fileManager.createDirectory(
            at: jobURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(job).write(to: jobURL, options: .atomic)
    }

    func clear() throws {
        guard let jobURL = jobURLProvider(), fileManager.fileExists(atPath: jobURL.path) else {
            return
        }
        try fileManager.removeItem(at: jobURL)
    }
}
