import Combine
import CryptoKit
import Foundation
import KeyVoxVibesAdapters

@MainActor
final class MacLocalRewriteModelManager: ObservableObject {
    private static let downloadProgressPublishInterval: Duration = .milliseconds(50)

    typealias DownloadClosure = @Sendable (
        URL,
        @escaping @Sendable (MacLocalRewriteModelDownloadProgressSnapshot) -> Void
    ) async throws -> URL

    @Published private(set) var installState: MacLocalRewriteModelInstallState = .notInstalled
    @Published private(set) var errorMessage: String?

    let fileManager: FileManager
    let appSupportRootURL: URL
    let descriptor: MacLocalRewriteModelDescriptor
    let download: DownloadClosure
    var installTask: Task<Void, Never>?
    var onDidInvalidateInstalledModel: (() -> Void)?
    private var pendingDownloadProgress: Double?
    private var downloadProgressPublishTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        appSupportRootURL: URL? = nil,
        descriptor: MacLocalRewriteModelDescriptor? = nil,
        download: DownloadClosure? = nil,
        refreshOnInit: Bool = true
    ) {
        self.fileManager = fileManager
        self.appSupportRootURL = appSupportRootURL ?? Self.defaultAppSupportRootURL(fileManager: fileManager)
        self.descriptor = descriptor ?? MacLocalRewriteModelCatalog.descriptor
        self.download = download ?? Self.defaultDownload(from:progress:)

        if refreshOnInit {
            refreshStatus()
        }
    }

    func refreshStatus() {
        guard installTask == nil else { return }
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

        return installedLoRAURL(filename: MacLocalRewriteModelCatalog.polishedLoRAFilename)
    }

    func casualLoRAURL() -> URL? {
        if let bundledAdapterURL = KeyVoxVibesAdapterCatalog.url(for: .casual) {
            return bundledAdapterURL
        }

        return installedLoRAURL(filename: MacLocalRewriteModelCatalog.casualLoRAFilename)
    }

    func isModelReady() -> Bool {
        guard let manifest = try? readManifest(from: manifestURL()),
              fileManager.fileExists(atPath: manifestURL().path),
              fileManager.fileExists(atPath: finalArtifactURL().path) else {
            return false
        }

        return manifest.modelID == descriptor.id
            && manifest.artifactFilename == descriptor.artifact.filename
            && manifest.expectedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
            && manifest.installedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
    }

    func downloadModel() {
        guard installTask == nil else { return }
        installTask = Task { [weak self] in
            await self?.performDownloadModel()
        }
    }

    func deleteModel() {
        onDidInvalidateInstalledModel?()
        installTask?.cancel()
        installTask = nil
        try? fileManager.removeItem(at: finalRootURL())
        try? fileManager.removeItem(at: stagingRootURL())
        refreshStatus()
    }

    private func installedLoRAURL(filename: String) -> URL? {
        guard isModelReady() else { return nil }
        let adapterURL = finalRootURL().appendingPathComponent(filename, isDirectory: false)
        return fileManager.fileExists(atPath: adapterURL.path) ? adapterURL : nil
    }

    private func performDownloadModel() async {
        defer {
            resetDownloadProgressPublishing()
            installTask = nil
        }

        do {
            resetDownloadProgressPublishing()
            setState(.downloading(progress: 0))
            try prepareCleanDirectory(stagingRootURL())

            let temporaryURL = try await download(descriptor.artifact.remoteURL) { [weak self] snapshot in
                Task { @MainActor [weak self] in
                    let progress = Self.progressFraction(
                        snapshot: snapshot,
                        fallbackExpectedBytes: self?.descriptor.artifact.progressTotalBytes ?? 1
                    )
                    self?.publishDownloadProgress(progress)
                }
            }

            flushDownloadProgress()
            setState(.installing(progress: 0.93))
            try fileManager.createDirectory(
                at: stagingArtifactURL().deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try replaceItem(at: stagingArtifactURL(), with: temporaryURL)

            setState(.installing(progress: 0.96))
            let installedHash = try sha256Hex(forFileAt: stagingArtifactURL())
            guard installedHash.lowercased() == descriptor.artifact.expectedSHA256.lowercased() else {
                throw MacLocalRewriteModelInstallError.integrityCheckFailed
            }

            setState(.installing(progress: 0.98))
            try prepareCleanDirectory(finalRootURL())
            try fileManager.moveItem(at: stagingArtifactURL(), to: finalArtifactURL())

            let manifest = MacLocalRewriteModelInstallManifest(
                modelID: descriptor.id,
                artifactFilename: descriptor.artifact.filename,
                sourceRepository: descriptor.sourceRepository,
                expectedSHA256: descriptor.artifact.expectedSHA256,
                installedSHA256: installedHash,
                fileSize: try fileSize(at: finalArtifactURL()),
                installedAt: Date()
            )
            try writeManifest(manifest, to: manifestURL())
            try? fileManager.removeItem(at: stagingRootURL())
            setState(.ready)
        } catch is CancellationError {
            setFailure(MacLocalRewriteModelManagerCopy.downloadCancelled)
        } catch {
            setFailure(Self.userFacingErrorMessage(for: error))
        }
    }

    private func finalRootURL() -> URL {
        appSupportRootURL
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("rewrite", isDirectory: true)
            .appendingPathComponent(descriptor.id, isDirectory: true)
    }

    private func stagingRootURL() -> URL {
        appSupportRootURL
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("rewrite", isDirectory: true)
            .appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent(descriptor.id, isDirectory: true)
    }

    private func finalArtifactURL() -> URL {
        finalRootURL().appendingPathComponent(descriptor.artifact.filename, isDirectory: false)
    }

    private func stagingArtifactURL() -> URL {
        stagingRootURL().appendingPathComponent(descriptor.artifact.filename, isDirectory: false)
    }

    private func manifestURL() -> URL {
        finalRootURL().appendingPathComponent(MacLocalRewriteModelCatalog.manifestFilename, isDirectory: false)
    }

    private func setState(_ state: MacLocalRewriteModelInstallState) {
        installState = state
        if case .failed(let message) = state {
            errorMessage = message
        } else {
            errorMessage = nil
        }
    }

    private func setFailure(_ message: String) {
        setState(.failed(message: message))
    }

    private func publishDownloadProgress(_ progress: Double) {
        pendingDownloadProgress = min(max(progress, 0), 0.92)

        guard downloadProgressPublishTask == nil else { return }
        downloadProgressPublishTask = Task { @MainActor [weak self] in
            while let self, let progress = self.pendingDownloadProgress {
                self.pendingDownloadProgress = nil
                self.setState(.downloading(progress: progress))
                try? await Task.sleep(for: Self.downloadProgressPublishInterval)
            }

            self?.downloadProgressPublishTask = nil
        }
    }

    private func flushDownloadProgress() {
        if let pendingDownloadProgress {
            self.pendingDownloadProgress = nil
            setState(.downloading(progress: pendingDownloadProgress))
        }

        downloadProgressPublishTask?.cancel()
        downloadProgressPublishTask = nil
    }

    private func resetDownloadProgressPublishing() {
        pendingDownloadProgress = nil
        downloadProgressPublishTask?.cancel()
        downloadProgressPublishTask = nil
    }

    private func prepareCleanDirectory(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func replaceItem(at destinationURL: URL, with sourceURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    private func writeManifest(_ manifest: MacLocalRewriteModelInstallManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    private func readManifest(from url: URL) throws -> MacLocalRewriteModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MacLocalRewriteModelInstallManifest.self, from: data)
    }

    private func sha256Hex(forFileAt url: URL) throws -> String {
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

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    nonisolated private static func defaultAppSupportRootURL(fileManager: FileManager) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupportURL.appendingPathComponent("KeyVox", isDirectory: true)
    }

    nonisolated private static func progressFraction(
        snapshot: MacLocalRewriteModelDownloadProgressSnapshot,
        fallbackExpectedBytes: Int64
    ) -> Double {
        let expectedBytes = max(snapshot.expectedBytes ?? fallbackExpectedBytes, fallbackExpectedBytes)
        guard expectedBytes > 0 else { return 0 }
        return Double(min(snapshot.completedBytes, expectedBytes)) / Double(expectedBytes)
    }

    private static func userFacingErrorMessage(for error: Error) -> String {
        if let installError = error as? MacLocalRewriteModelInstallError {
            return installError.localizedDescription
        }
        return MacLocalRewriteModelManagerCopy.downloadFailed
    }

    nonisolated static func defaultDownload(
        from url: URL,
        progress: @escaping @Sendable (MacLocalRewriteModelDownloadProgressSnapshot) -> Void
    ) async throws -> URL {
        progress(.zero)
        let downloadTaskBox = MacLocalRewriteModelDownloadTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let delegate = MacLocalRewriteModelDownloadDelegate(
                    sourceURL: url,
                    progress: progress
                ) { result in
                    continuation.resume(with: result)
                }
                let session = URLSession(
                    configuration: .default,
                    delegate: delegate,
                    delegateQueue: nil
                )
                delegate.session = session
                let task = session.downloadTask(with: url)
                Task {
                    await downloadTaskBox.set(task)
                    task.resume()
                }
            }
        } onCancel: {
            Task {
                await downloadTaskBox.cancel()
            }
        }
    }
}

private actor MacLocalRewriteModelDownloadTaskBox {
    private var task: URLSessionDownloadTask?
    private var isCancelled = false

    func set(_ task: URLSessionDownloadTask) {
        self.task = task
        let shouldCancel = isCancelled

        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        isCancelled = true
        let currentTask = task
        currentTask?.cancel()
    }
}

enum MacLocalRewriteModelInstallError: LocalizedError {
    case integrityCheckFailed

    var errorDescription: String? {
        switch self {
        case .integrityCheckFailed:
            return MacLocalRewriteModelManagerCopy.integrityCheckFailed
        }
    }
}

private enum MacLocalRewriteModelManagerCopy {
    static let downloadFailed = "Vibes model download failed. Check your network/storage and retry."
    static let downloadCancelled = "Vibes model download was cancelled."
    static let integrityCheckFailed = "Downloaded Vibes model did not match the expected SHA-256."
}

struct MacLocalRewriteModelDownloadProgressSnapshot: Sendable {
    let fractionCompleted: Double
    let completedBytes: Int64
    let expectedBytes: Int64?

    nonisolated init(
        fractionCompleted: Double,
        completedBytes: Int64,
        expectedBytes: Int64?
    ) {
        self.fractionCompleted = fractionCompleted
        self.completedBytes = completedBytes
        self.expectedBytes = expectedBytes
    }

    nonisolated static let zero = MacLocalRewriteModelDownloadProgressSnapshot(
        fractionCompleted: 0,
        completedBytes: 0,
        expectedBytes: nil
    )

    nonisolated static let complete = MacLocalRewriteModelDownloadProgressSnapshot(
        fractionCompleted: 1,
        completedBytes: 1,
        expectedBytes: 1
    )
}

final class MacLocalRewriteModelDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let sourceURL: URL
    private let progressHandler: @Sendable (MacLocalRewriteModelDownloadProgressSnapshot) -> Void
    private let completion: @Sendable (Result<URL, Error>) -> Void
    private let lock = NSLock()
    private var hasCompleted = false
    weak var session: URLSession?

    init(
        sourceURL: URL,
        progress: @escaping @Sendable (MacLocalRewriteModelDownloadProgressSnapshot) -> Void,
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        self.sourceURL = sourceURL
        self.progressHandler = progress
        self.completion = completion
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expectedBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        let fractionCompleted = expectedBytes.map { Double(totalBytesWritten) / Double($0) } ?? 0
        progressHandler(
            MacLocalRewriteModelDownloadProgressSnapshot(
                fractionCompleted: min(max(fractionCompleted, 0), 1),
                completedBytes: max(totalBytesWritten, 0),
                expectedBytes: expectedBytes
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            let stableURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent(sourceURL.lastPathComponent, isDirectory: false)
            try FileManager.default.createDirectory(
                at: stableURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: location, to: stableURL)
            progressHandler(.complete)
            finish(.success(stableURL))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let shouldComplete = !hasCompleted
        hasCompleted = true
        lock.unlock()

        guard shouldComplete else { return }
        session?.finishTasksAndInvalidate()
        completion(result)
    }
}
