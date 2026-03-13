import Foundation

struct iOSModelBackgroundDownloadJobStore {
    let fileManager: FileManager
    let jobURLProvider: () -> URL?

    func load() -> iOSModelBackgroundDownloadJob? {
        guard let jobURL = jobURLProvider(),
              fileManager.fileExists(atPath: jobURL.path),
              let data = try? Data(contentsOf: jobURL) else {
            return nil
        }

        return try? JSONDecoder().decode(iOSModelBackgroundDownloadJob.self, from: data)
    }

    func save(_ job: iOSModelBackgroundDownloadJob) throws {
        guard let jobURL = jobURLProvider() else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directoryURL = jobURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(job)
        try data.write(to: jobURL, options: .atomic)
    }

    func clear() throws {
        guard let jobURL = jobURLProvider(),
              fileManager.fileExists(atPath: jobURL.path) else {
            return
        }

        try fileManager.removeItem(at: jobURL)
    }
}
