import Foundation
import FoundationNetworking
import KeyVoxModels
import CAndroidEngine

struct EncoderArtifactInstaller: Sendable {
    let directory: URL
    let artifact: WhisperEncoderArtifact
    var modelURL: URL { directory.appendingPathComponent(artifact.filename) }

    func isReady() -> Bool {
        artifact.baseModelSHA256 == WhisperBaseModelArtifact.sha256 &&
        (try? ModelFileIntegrity.sha256Hex(forFileAt: modelURL)) == artifact.sha256
    }

    func install() async throws {
        guard !isReady() else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let (archive, response) = try await URLSession.shared.download(from: artifact.downloadURL)
        defer { try? FileManager.default.removeItem(at: archive) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              try ModelFileIntegrity.sha256Hex(forFileAt: archive) == artifact.archiveSHA256 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let temporary = directory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let extracted = archive.path.withCString { archivePath in
            artifact.archiveMember.withCString { member in
                temporary.path.withCString { destination in
                    keyvox_extract_model_member(archivePath, member, destination, artifact.byteCount) != 0
                }
            }
        }
        guard extracted, try ModelFileIntegrity.sha256Hex(forFileAt: temporary) == artifact.sha256 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if FileManager.default.fileExists(atPath: modelURL.path) {
            _ = try FileManager.default.replaceItemAt(modelURL, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: modelURL)
        }
    }
}
