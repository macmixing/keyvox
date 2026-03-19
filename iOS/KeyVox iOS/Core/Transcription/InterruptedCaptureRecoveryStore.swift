import Foundation

struct InterruptedCaptureRecoveryStore {
    let fileManager: FileManager
    let recoveryURLProvider: () -> URL?

    func load() -> InterruptedCaptureRecoveryPayload? {
        guard let recoveryURL = recoveryURLProvider(),
              fileManager.fileExists(atPath: recoveryURL.path),
              let data = try? Data(contentsOf: recoveryURL) else {
            return nil
        }

        return try? PropertyListDecoder().decode(InterruptedCaptureRecoveryPayload.self, from: data)
    }

    func save(_ payload: InterruptedCaptureRecoveryPayload) throws {
        guard let recoveryURL = recoveryURLProvider() else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directoryURL = recoveryURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(payload)
        try data.write(to: recoveryURL, options: .atomic)
    }

    func clear() throws {
        guard let recoveryURL = recoveryURLProvider(),
              fileManager.fileExists(atPath: recoveryURL.path) else {
            return
        }

        try fileManager.removeItem(at: recoveryURL)
    }
}
