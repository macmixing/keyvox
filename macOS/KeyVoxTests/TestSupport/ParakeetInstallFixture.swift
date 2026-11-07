import Foundation
@testable import KeyVox

@MainActor
enum ParakeetInstallFixture {
    static var currentArtifacts: [DictationModelArtifact] {
        DictationModelCatalog.descriptor(for: .parakeetTdtV3).artifacts
    }

    static var legacyArtifacts: [DictationModelArtifact] {
        DictationModelCatalog.legacyParakeetArtifacts
    }

    static func makeDownloader(
        in directory: URL,
        makeDownloadSession: ModelDownloader.SessionFactory? = nil
    ) -> ModelDownloader {
        let modelURL = directory
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("whisper", isDirectory: true)
            .appendingPathComponent("ggml-base.bin")

        if let makeDownloadSession {
            return ModelDownloader(
                fileManager: FileManager.default,
                modelURLOverride: modelURL,
                refreshOnInit: false,
                freeSpaceProvider: { _ in nil },
                environmentProvider: { [:] },
                makeDownloadSession: makeDownloadSession
            )
        }

        return ModelDownloader(
            fileManager: FileManager.default,
            modelURLOverride: modelURL,
            refreshOnInit: false,
            freeSpaceProvider: { _ in nil },
            environmentProvider: { [:] }
        )
    }

    /// Writes placeholder artifact files plus an install manifest that lists them.
    static func writeInstall(_ artifacts: [DictationModelArtifact], at rootURL: URL) throws {
        let fileManager = FileManager.default
        var hashes: [String: String] = [:]

        for artifact in artifacts {
            let url = artifact.relativePath.split(separator: "/").reduce(rootURL) { url, component in
                url.appendingPathComponent(String(component), isDirectory: false)
            }
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([0x01]).write(to: url, options: .atomic)
            hashes[artifact.relativePath] = artifact.expectedSHA256
        }

        let manifest = DictationModelInstallManifest(
            version: DictationModelInstallManifest.currentVersion,
            artifactSHA256ByRelativePath: hashes
        )
        try JSONEncoder().encode(manifest).write(
            to: rootURL.appendingPathComponent(DictationModelCatalog.manifestFilename, isDirectory: false),
            options: .atomic
        )
    }
}
