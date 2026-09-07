import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import KeyVoxCore

/// Verifies foreground transport only; the caller must verify integrity before use.
enum WhisperDownloadProbe {
    enum Failure: Error { case unexpectedResponse }

    private struct Report: Encodable {
        let downloadedPath: String
        let expectedSHA256: String
        let bytes: UInt64
        let integrityVerified = false
    }

    static func run(directoryPath: String) async throws {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let destination = directory.appendingPathComponent(WhisperBaseModelArtifact.filename)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw CocoaError(.fileWriteFileExists)
        }

        let (temporaryURL, response) = try await URLSession.shared.download(
            from: WhisperBaseModelArtifact.downloadURL
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw Failure.unexpectedResponse
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw CocoaError(.fileReadUnknown)
        }
        let report = Report(downloadedPath: destination.path,
                            expectedSHA256: WhisperBaseModelArtifact.sha256,
                            bytes: size.uint64Value)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }
}
