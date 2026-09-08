import Foundation
import FoundationNetworking
import KeyVoxModels

struct ModelArtifactInstaller: Sendable {
    let directory: URL
    var modelURL: URL { directory.appendingPathComponent(WhisperBaseModelArtifact.filename) }

    func isReady() -> Bool {
        (try? ModelFileIntegrity.sha256Hex(forFileAt: modelURL)) == WhisperBaseModelArtifact.sha256
    }

    func install() async throws {
        if isReady() { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let (temporary, response) = try await URLSession.shared.download(from: WhisperBaseModelArtifact.downloadURL)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              try ModelFileIntegrity.sha256Hex(forFileAt: temporary) == WhisperBaseModelArtifact.sha256 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // The destination only becomes visible after verification. Existing invalid
        // weights are retained until the replacement has been verified.
        if FileManager.default.fileExists(atPath: modelURL.path) {
            _ = try FileManager.default.replaceItemAt(modelURL, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: modelURL)
        }
    }
}
