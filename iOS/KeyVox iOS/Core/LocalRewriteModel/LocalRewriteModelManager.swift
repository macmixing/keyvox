import Combine
import CryptoKit
import Foundation
import KeyVoxVibesAdapters

@MainActor
final class LocalRewriteModelManager: ObservableObject {
    @Published private(set) var installState: LocalRewriteModelInstallState = .notInstalled
    @Published private(set) var errorMessage: String?

    let fileManager: FileManager
    let descriptor: LocalRewriteModelDescriptor
    let backgroundDownloadCoordinator: LocalRewriteBackgroundDownloadCoordinator
    var installTask: Task<Void, Never>?
    var activationRecoveryTask: Task<Void, Never>?
    var onDidInvalidateInstalledModel: (() -> Void)?
    var appIsActive = false
    var isFinalizationInFlight = false

    init(
        fileManager: FileManager = .default,
        descriptor: LocalRewriteModelDescriptor? = nil,
        backgroundDownloadCoordinator: LocalRewriteBackgroundDownloadCoordinator
    ) {
        self.fileManager = fileManager
        self.descriptor = descriptor ?? LocalRewriteModelCatalog.descriptor
        self.backgroundDownloadCoordinator = backgroundDownloadCoordinator
        self.backgroundDownloadCoordinator.stateDidChange = { [weak self] job in
            Task { @MainActor [weak self] in
                await self?.handleBackgroundDownloadStateChanged(job)
            }
        }
        refreshStatus()
    }

    func refreshStatus() {
        if let job = backgroundDownloadCoordinator.loadJob() {
            applyBackgroundJobState(job)
            return
        }
        installState = isModelReady() ? .ready : .notInstalled
        errorMessage = nil
    }

    func installedModelURL() -> URL? {
        guard isModelReady() else { return nil }
        return finalArtifactURL()
    }

    func polishedLoRAURL() -> URL? {
        if let bundledAdapterURL = KeyVoxVibesAdapterCatalog.url(for: .polished) {
            return bundledAdapterURL
        }

        return installedLoRAURL(filename: LocalRewriteModelCatalog.polishedLoRAFilename)
    }

    func casualLoRAURL() -> URL? {
        if let bundledAdapterURL = KeyVoxVibesAdapterCatalog.url(for: .casual) {
            return bundledAdapterURL
        }

        return installedLoRAURL(filename: LocalRewriteModelCatalog.casualLoRAFilename)
    }

    private func installedLoRAURL(filename: String) -> URL? {
        guard isModelReady() else { return nil }
        guard let adapterURL = finalRootURL()?.appendingPathComponent(
            filename,
            isDirectory: false
        ) else {
            return nil
        }

        return fileManager.fileExists(atPath: adapterURL.path) ? adapterURL : nil
    }

    func isModelReady() -> Bool {
        guard let manifestURL = manifestURL(),
              let artifactURL = finalArtifactURL(),
              fileManager.fileExists(atPath: manifestURL.path),
              fileManager.fileExists(atPath: artifactURL.path),
              let manifest = try? readManifest(from: manifestURL) else {
            return false
        }

        return manifest.modelID == descriptor.id
            && manifest.artifactFilename == descriptor.artifact.filename
            && manifest.expectedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
            && manifest.installedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
    }

    func finalRootURL() -> URL? {
        SharedPaths.localRewriteModelDirectoryURL(fileManager: fileManager)
    }

    func stagingRootURL() -> URL? {
        SharedPaths.localRewriteModelStagingDirectoryURL(fileManager: fileManager)
    }

    func finalArtifactURL() -> URL? {
        finalRootURL()?.appendingPathComponent(descriptor.artifact.filename, isDirectory: false)
    }

    func stagingArtifactURL() -> URL? {
        stagingRootURL()?.appendingPathComponent(descriptor.artifact.filename, isDirectory: false)
    }

    func manifestURL() -> URL? {
        finalRootURL()?.appendingPathComponent(LocalRewriteModelCatalog.manifestFilename, isDirectory: false)
    }

    func setState(_ state: LocalRewriteModelInstallState) {
        installState = state
        if case .failed(let message) = state {
            errorMessage = message
        } else {
            errorMessage = nil
        }
    }

    func setFailure(_ message: String) {
        setState(.failed(message: message))
    }

    func prepareCleanDirectory(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeManifest(_ manifest: LocalRewriteModelInstallManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    func readManifest(from url: URL) throws -> LocalRewriteModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LocalRewriteModelInstallManifest.self, from: data)
    }

    func sha256Hex(forFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1_048_576)
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    nonisolated static func userFacingErrorMessage(for error: Error) -> String {
        if let installError = error as? LocalRewriteModelInstallError {
            return installError.localizedDescription
        }
        return "Vibes model download failed. Check your network/storage and retry."
    }

}

enum LocalRewriteModelInstallError: LocalizedError {
    case appGroupUnavailable
    case integrityCheckFailed

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "App Group container unavailable."
        case .integrityCheckFailed:
            return "Downloaded Vibes model did not match the expected SHA-256."
        }
    }
}
