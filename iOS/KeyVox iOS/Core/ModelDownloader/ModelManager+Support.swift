import CryptoKit
import Foundation
import ZIPFoundation

extension ModelManager {
    func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        try removeItemIfExists(at: destinationURL)
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        Self.debugLog("moveDownloadedFile: \(sourceURL.lastPathComponent) -> \(destinationURL.path)")
    }

    func removeItemIfExists(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func writeManifest(_ manifest: ModelInstallManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try removeItemIfExists(at: url)
        try data.write(to: url, options: .atomic)
        Self.debugLog("writeManifest: wrote \(url.path)")
    }

    func readManifest(from url: URL) throws -> ModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ModelInstallManifest.self, from: data)
    }

    nonisolated static func defaultDownload(
        from url: URL,
        progress: @escaping @Sendable (ModelDownloadProgressSnapshot) -> Void
    ) async throws -> URL {
        progress(.zero)
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = ModelDownloadDelegate(
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
            task.resume()
        }
    }

    nonisolated static func defaultUnzip(
        zipURL: URL,
        destinationDirectory: URL,
        fileManager: FileManager,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        let archive = try Archive(url: zipURL, accessMode: .read)
        let totalBytes = archive.reduce(into: Int64(0)) { partialResult, entry in
            partialResult += Int64(entry.uncompressedSize)
        }
        var completedBytes: Int64 = 0
        progress(0, totalBytes)

        for entry in archive {
            let destinationURL = destinationDirectory.appendingPathComponent(entry.path)
            let parentDirectory = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }
            _ = try archive.extract(entry, to: destinationURL)
            completedBytes += Int64(entry.uncompressedSize)
            progress(completedBytes, totalBytes)
        }
    }

    nonisolated static func defaultFreeSpaceProvider(at url: URL) -> Int64? {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let resourceValues = try? url.resourceValues(forKeys: keys) else {
            return nil
        }
        if let capacity = resourceValues.volumeAvailableCapacityForImportantUsage {
            return Int64(capacity)
        }
        if let capacity = resourceValues.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return nil
    }

    nonisolated static func userFacingErrorMessage(for error: Error) -> String {
        if let modelError = error as? ModelInstallError {
            return modelError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return "Model download failed due to low disk space. Free space and try again."
        }
        return "Model download failed. Check your network/storage and retry."
    }

    nonisolated static func sha256Hex(
        forFileAt url: URL,
        progress: ((Int64, Int64) -> Void)? = nil
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let totalBytes = Int64((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0)
        var completedBytes: Int64 = 0
        progress?(0, totalBytes)
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1_048_576)
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            completedBytes += Int64(data.count)
            progress?(completedBytes, totalBytes)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func validateExtractedCoreMLBundle(at rootURL: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return "Model install is incomplete. Missing ggml-base-encoder.mlmodelc."
        }

        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var regularFileCount = 0
        while let entry = enumerator?.nextObject() as? URL {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == false {
                regularFileCount += 1
            }
        }

        debugLog("validateExtractedCoreMLBundle: regularFileCount=\(regularFileCount) root=\(rootURL.path)")
        guard regularFileCount > 0 else {
            return "The extracted Core ML bundle was empty after installation."
        }

        return nil
    }

    nonisolated static func directoryDigestHex(
        at rootURL: URL,
        fileManager: FileManager,
        progress: ((Int64, Int64) -> Void)? = nil
    ) throws -> String {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            throw ModelInstallError.integrityCheckFailed("Missing extracted Core ML bundle for integrity verification.")
        }

        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var fileURLs: [URL] = []
        while let entry = enumerator?.nextObject() as? URL {
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == false {
                fileURLs.append(entry)
            }
        }

        fileURLs.sort { $0.path < $1.path }
        debugLog("directoryDigestHex: hashing \(fileURLs.count) files under \(rootURL.path)")
        let totalBytes = fileURLs.reduce(into: Int64(0)) { partialResult, fileURL in
            let fileSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            partialResult += fileSize
        }
        var completedBytes: Int64 = 0
        progress?(0, totalBytes)
        var hasher = SHA256()
        for fileURL in fileURLs {
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            hasher.update(data: Data(relativePath.utf8))
            hasher.update(data: Data([0]))
            let fileHash = try sha256Hex(forFileAt: fileURL) { fileCompleted, _ in
                progress?(completedBytes + fileCompleted, totalBytes)
            }
            debugLog("directoryDigestHex: \(relativePath) -> \(fileHash)")
            hasher.update(data: Data(fileHash.utf8))
            hasher.update(data: Data([0]))
            let fileSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            completedBytes += fileSize
            progress?(completedBytes, totalBytes)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func debugLog(_ message: String) {
#if DEBUG
        print("[ModelManager] \(message)")
#endif
    }
}

struct ModelDownloadProgressSnapshot: Sendable {
    let fractionCompleted: Double
    let completedBytes: Int64
    let expectedBytes: Int64?

    nonisolated static let zero = ModelDownloadProgressSnapshot(
        fractionCompleted: 0,
        completedBytes: 0,
        expectedBytes: nil
    )

    nonisolated static let complete = ModelDownloadProgressSnapshot(
        fractionCompleted: 1,
        completedBytes: 1,
        expectedBytes: 1
    )
}

actor ModelDownloadAggregateProgress {
    private let artifactsByRelativePath: [String: DictationModelArtifact]
    private var snapshotsByRelativePath: [String: ModelDownloadProgressSnapshot]

    init(artifacts: [DictationModelArtifact]) {
        artifactsByRelativePath = Dictionary(
            uniqueKeysWithValues: artifacts.map { ($0.relativePath, $0) }
        )
        snapshotsByRelativePath = Dictionary(
            uniqueKeysWithValues: artifacts.map { ($0.relativePath, .zero) }
        )
    }

    func update(_ snapshot: ModelDownloadProgressSnapshot, for relativePath: String) {
        snapshotsByRelativePath[relativePath] = snapshot
    }

    func overallFraction() -> Double {
        let expectedBytes = artifactsByRelativePath.values.reduce(into: Int64(0)) { total, artifact in
            let snapshot = snapshotsByRelativePath[artifact.relativePath] ?? .zero
            total += max(snapshot.expectedBytes ?? artifact.progressTotalBytes, artifact.progressTotalBytes)
        }

        guard expectedBytes > 0 else { return 0 }

        let completedBytes = artifactsByRelativePath.values.reduce(into: Int64(0)) { total, artifact in
            let snapshot = snapshotsByRelativePath[artifact.relativePath] ?? .zero
            let artifactExpected = max(snapshot.expectedBytes ?? artifact.progressTotalBytes, artifact.progressTotalBytes)
            total += min(snapshot.completedBytes, artifactExpected)
        }

        return min(max(Double(completedBytes) / Double(expectedBytes), 0), 1)
    }
}

enum ModelInstallError: LocalizedError {
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case unzipFailed(String)
    case integrityCheckFailed(String)

    var errorDescription: String? {
        switch self {
        case let .insufficientDiskSpace(requiredBytes, availableBytes):
            let required = ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file)
            let available = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
            return "Not enough free disk space to install the model (\(available) available, \(required) required)."
        case let .unzipFailed(message):
            return message
        case let .integrityCheckFailed(message):
            return message
        }
    }
}

final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let sourceURL: URL
    private let progressHandler: @Sendable (ModelDownloadProgressSnapshot) -> Void
    private let completion: @Sendable (Result<URL, Error>) -> Void
    private let lock = NSLock()
    private var hasCompleted = false
    weak var session: URLSession?

    init(
        sourceURL: URL,
        progress: @escaping @Sendable (ModelDownloadProgressSnapshot) -> Void,
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
        let fractionCompleted: Double
        if let expectedBytes, expectedBytes > 0 {
            fractionCompleted = min(max(Double(totalBytesWritten) / Double(expectedBytes), 0), 1)
        } else {
            fractionCompleted = 0
        }

        progressHandler(
            ModelDownloadProgressSnapshot(
                fractionCompleted: fractionCompleted,
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
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(sourceURL.lastPathComponent)
            let parentDirectory = stableURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }
            if FileManager.default.fileExists(atPath: stableURL.path) {
                try FileManager.default.removeItem(at: stableURL)
            }
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
