import Combine
import Foundation

enum PocketTTSInstallState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case installing(progress: Double)
    case ready
    case failed(String)

    var statusText: String {
        switch self {
        case .notInstalled:
            return "Not installed"
        case .downloading:
            return "Downloading playback model"
        case .installing:
            return "Installing playback model"
        case .ready:
            return "Installed"
        case .failed:
            return "Install failed"
        }
    }
}

@MainActor
final class PocketTTSModelManager: ObservableObject {
    @Published private(set) var installState: PocketTTSInstallState = .notInstalled

    private let fileManager: FileManager
    private let session: URLSession
    private let assetLocator: PocketTTSAssetLocator
    private var installTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        assetLocator: PocketTTSAssetLocator? = nil
    ) {
        self.fileManager = fileManager
        self.session = session
        self.assetLocator = assetLocator ?? PocketTTSAssetLocator(fileManager: fileManager)
        refreshStatus()
    }

    func refreshStatus() {
        guard installTask == nil else { return }
        installState = assetLocator.isInstalled() ? .ready : .notInstalled
    }

    func handleAppDidBecomeActive() {
        refreshStatus()
    }

    func handleAppDidEnterBackground() {}

    func downloadModel() {
        guard installTask == nil else { return }

        installTask = Task { [fileManager, session] in
            do {
                Self.log("Install requested.")
                await MainActor.run {
                    self.installState = .downloading(progress: 0)
                }

                let descriptor = try await PocketTTSModelCatalog.fetchDescriptor(session: session)
                Self.log("Fetched descriptor with \(descriptor.artifacts.count) artifacts (\(descriptor.requiredDownloadBytes) bytes).")
                let stagingRootURL = try Self.makeStagingRootURL(fileManager: fileManager)
                try Self.prepareDirectory(stagingRootURL, fileManager: fileManager)
                Self.log("Prepared staging directory at \(stagingRootURL.path).")

                var completedBytes: Int64 = 0
                let totalBytes = max(descriptor.requiredDownloadBytes, 1)

                for artifact in descriptor.artifacts {
                    let destinationURL = stagingRootURL.appendingPathComponent(artifact.relativePath, isDirectory: false)
                    try Self.prepareParentDirectory(for: destinationURL, fileManager: fileManager)
                    if artifact.expectedByteCount == 0 {
                        Self.log("Creating empty artifact \(artifact.relativePath).")
                        try Data().write(to: destinationURL, options: [.atomic])
                    } else {
                        Self.log("Downloading artifact \(artifact.relativePath) from \(artifact.remoteURL.absoluteString).")
                        let temporaryURL = try await Self.download(artifact.remoteURL, using: session)
                        try Self.replaceItem(at: destinationURL, with: temporaryURL, fileManager: fileManager)
                        Self.log("Stored artifact \(artifact.relativePath) at \(destinationURL.path).")
                    }
                    completedBytes += artifact.expectedByteCount

                    let progress = min(max(Double(completedBytes) / Double(totalBytes), 0), 0.92)
                    await MainActor.run {
                        self.installState = .downloading(progress: progress)
                    }
                }

                await MainActor.run {
                    self.installState = .installing(progress: 0.95)
                }
                Self.log("All downloads completed. Writing manifest.")

                let manifest = PocketTTSInstallManifest(
                    sourceRepository: PocketTTSModelCatalog.repositoryID,
                    artifactSizesByRelativePath: Dictionary(
                        uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedByteCount) }
                    )
                )
                try Self.writeManifest(manifest, to: stagingRootURL)
                Self.log("Manifest written.")

                let finalRootURL = try Self.finalRootURL(fileManager: fileManager)
                try Self.replaceDirectory(at: finalRootURL, with: stagingRootURL, fileManager: fileManager)
                Self.log("Moved staged install into final directory \(finalRootURL.path).")

                let installed = self.assetLocator.isInstalled()
                Self.log("Post-install validation result: \(installed ? "ready" : "invalid").")
                guard installed else {
                    throw NSError(
                        domain: "PocketTTSModelManager",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "PocketTTS install validation failed."]
                    )
                }

                await MainActor.run {
                    self.installState = .ready
                }
                Self.log("Install completed successfully.")
            } catch {
                Self.log("Install failed with error: \(error.localizedDescription)")
                await MainActor.run {
                    self.installState = .failed(error.localizedDescription)
                }
            }

            await MainActor.run {
                self.installTask = nil
            }
        }
    }

    func deleteModel() {
        Self.log("Deleting installed PocketTTS assets.")
        installTask?.cancel()
        installTask = nil

        guard let rootURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            installState = .notInstalled
            return
        }

        try? fileManager.removeItem(at: rootURL)
        refreshStatus()
    }

    func repairModelIfNeeded() {
        deleteModel()
        downloadModel()
    }

    private static func finalRootURL(fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the PocketTTS install directory."]
            )
        }
        return rootURL
    }

    private static func makeStagingRootURL(fileManager: FileManager) throws -> URL {
        guard let ttsDirectoryURL = SharedPaths.ttsDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create the PocketTTS staging directory."]
            )
        }

        let stagingRootURL = ttsDirectoryURL
            .appendingPathComponent("staging", isDirectory: true)
            .appendingPathComponent("pockettts", isDirectory: true)
        return stagingRootURL
    }

    private static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: url.path) {
            log("Removing stale staging directory at \(url.path).")
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func prepareParentDirectory(for url: URL, fileManager: FileManager) throws {
        let parentURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
    }

    private static func download(_ url: URL, using session: URLSession) async throws -> URL {
        let (temporaryURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            log("Download request failed for \(url.absoluteString).")
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "PocketTTS download failed."]
            )
        }
        log("Download request succeeded for \(url.absoluteString) with status \(httpResponse.statusCode).")
        return temporaryURL
    }

    private static func replaceItem(at destinationURL: URL, with temporaryURL: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    private static func writeManifest(_ manifest: PocketTTSInstallManifest, to rootURL: URL) throws {
        let manifestURL = rootURL.appendingPathComponent(PocketTTSInstallManifest.filename, isDirectory: false)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private static func replaceDirectory(at destinationURL: URL, with stagingURL: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            log("Removing previous install at \(destinationURL.path).")
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
    }

    private static func log(_ message: String) {
        NSLog("[PocketTTSModelManager] %@", message)
    }
}
