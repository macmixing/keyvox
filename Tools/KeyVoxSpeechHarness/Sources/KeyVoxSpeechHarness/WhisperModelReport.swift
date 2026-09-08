import Foundation
import KeyVoxModels

/// Exposes the shared artifact definition for host download/integrity checks.
enum WhisperModelReport {
    static func printArtifact() throws {
        let fields = [
            "filename": WhisperBaseModelArtifact.filename,
            "revision": WhisperBaseModelArtifact.revision,
            "downloadURL": WhisperBaseModelArtifact.downloadURL.absoluteString,
            "sha256": WhisperBaseModelArtifact.sha256,
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(fields)
        print(String(decoding: data, as: UTF8.self))
    }
}
