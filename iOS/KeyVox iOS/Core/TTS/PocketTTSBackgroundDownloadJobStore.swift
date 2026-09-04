import Foundation

struct PocketTTSBackgroundDownloadJobStore {
    let fileManager: FileManager
    let jobURLProvider: () -> URL?

    func load() -> PocketTTSBackgroundDownloadJob? {
        guard let jobURL = jobURLProvider(),
              fileManager.fileExists(atPath: jobURL.path),
              let data = try? Data(contentsOf: jobURL) else {
            return nil
        }
        return try? JSONDecoder().decode(PocketTTSBackgroundDownloadJob.self, from: data)
    }

    func save(_ job: PocketTTSBackgroundDownloadJob) throws {
        guard let jobURL = jobURLProvider() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directoryURL = jobURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
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
