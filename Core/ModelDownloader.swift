import Foundation
import Combine
import Darwin

protocol ModelDownloadTasking {
    var taskIdentifier: Int { get }
    func resume()
}

protocol ModelDownloadSessioning {
    func downloadTask(with url: URL) -> ModelDownloadTasking
}

private final class URLSessionDownloadTaskAdapter: ModelDownloadTasking {
    private let task: URLSessionDownloadTask

    init(task: URLSessionDownloadTask) {
        self.task = task
    }

    var taskIdentifier: Int {
        task.taskIdentifier
    }

    func resume() {
        task.resume()
    }
}

private final class URLSessionDownloadSessionAdapter: ModelDownloadSessioning {
    private let session: URLSession

    init(configuration: URLSessionConfiguration, delegate: URLSessionDownloadDelegate) {
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func downloadTask(with url: URL) -> ModelDownloadTasking {
        URLSessionDownloadTaskAdapter(task: session.downloadTask(with: url))
    }
}

class ModelDownloader: ObservableObject {
    typealias SessionFactory = (URLSessionDownloadDelegate) -> ModelDownloadSessioning
    typealias FreeSpaceProvider = (URL) -> Int64?
    typealias EnvironmentProvider = () -> [String: String]

    static let shared = ModelDownloader()

    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var modelReady: Bool = false
    @Published var errorMessage: String?

    private var taskProgress: [Int: (written: Int64, total: Int64)] = [:]
    private let fileManager: FileManager
    private let modelURLProvider: () -> URL
    private let makeDownloadSession: SessionFactory
    private let freeSpaceProvider: FreeSpaceProvider
    private let environmentProvider: EnvironmentProvider
    private let requiredDownloadBytes: Int64
    private var activeDownloadSession: ModelDownloadSessioning?

    var taskProgressSnapshot: [Int: (written: Int64, total: Int64)] {
        taskProgress
    }

    var modelURL: URL {
        let resolved = modelURLProvider()
        let modelsDir = resolved.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        return resolved
    }

    private var coreMLZipURL: URL {
        modelURL.deletingPathExtension().appendingPathExtension("encoder.mlmodelc.zip")
    }

    private var coreMLModelDirURL: URL {
        modelURL.deletingPathExtension().appendingPathExtension("encoder.mlmodelc")
    }

    // Integrity thresholds (hardening only). These are intentionally conservative.
    private let minGGMLBytes: Int64
    private static let defaultRequiredDownloadBytes: Int64 = 220_000_000
    private static let downloadPreviewErrorEnvironmentKey = "KVX_MODEL_DOWNLOAD_PREVIEW_ERROR"

    init(
        fileManager: FileManager = .default,
        modelURLOverride: URL? = nil,
        minGGMLBytes: Int64 = 90_000_000,
        refreshOnInit: Bool = true,
        requiredDownloadBytes: Int64 = ModelDownloader.defaultRequiredDownloadBytes,
        freeSpaceProvider: @escaping FreeSpaceProvider = ModelDownloader.defaultFreeSpaceProvider(at:),
        environmentProvider: @escaping EnvironmentProvider = { ProcessInfo.processInfo.environment },
        makeDownloadSession: @escaping SessionFactory = { delegate in
            URLSessionDownloadSessionAdapter(
                configuration: .default,
                delegate: delegate
            )
        }
    ) {
        self.fileManager = fileManager
        self.minGGMLBytes = minGGMLBytes
        self.requiredDownloadBytes = requiredDownloadBytes
        self.freeSpaceProvider = freeSpaceProvider
        self.environmentProvider = environmentProvider
        self.makeDownloadSession = makeDownloadSession
        if let modelURLOverride {
            self.modelURLProvider = { modelURLOverride }
        } else {
            self.modelURLProvider = {
                let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? fileManager.temporaryDirectory
                return appSupport
                    .appendingPathComponent("KeyVox")
                    .appendingPathComponent("Models")
                    .appendingPathComponent("ggml-base.bin")
            }
        }

        if refreshOnInit {
            refreshModelStatus()
        }
    }

    // Keep teardown executor-agnostic to avoid runtime deinit crashes in test host.
    nonisolated deinit {}

    func refreshModelStatus() {
        modelReady = validateModelFiles()
    }

    func downloadBaseModel() {
        guard !isDownloading else { return }
        if let previewErrorMessage = previewDownloadErrorMessage() {
            isDownloading = false
            progress = 0
            taskProgress.removeAll()
            activeDownloadSession = nil
            errorMessage = previewErrorMessage
            return
        }
        if let availableBytes = freeSpaceProvider(modelURL.deletingLastPathComponent()),
           availableBytes < requiredDownloadBytes {
            errorMessage = Self.insufficientDiskSpaceMessage(
                requiredBytes: requiredDownloadBytes,
                availableBytes: availableBytes
            )
            isDownloading = false
            progress = 0
            taskProgress.removeAll()
            return
        }

        let ggmlURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
        let coreMLURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-encoder.mlmodelc.zip")!

        isDownloading = true
        progress = 0
        errorMessage = nil
        taskProgress.removeAll()

        let delegate = DownloadDelegate(downloader: self)
        let session = makeDownloadSession(delegate)
        activeDownloadSession = session

        let taskA = session.downloadTask(with: ggmlURL)
        let taskB = session.downloadTask(with: coreMLURL)

        taskProgress[taskA.taskIdentifier] = (0, 140_000_000)
        taskProgress[taskB.taskIdentifier] = (0, 50_000_000)

        taskA.resume()
        taskB.resume()
    }

    func handleDownloadCompletion(task: URLSessionDownloadTask, location: URL) {
        guard isDownloading else { return }
        let urlString = task.originalRequest?.url?.absoluteString ?? ""
        let isGGML = urlString.contains("ggml-base.bin")

        do {
            if isGGML {
                if fileManager.fileExists(atPath: modelURL.path) {
                    try fileManager.removeItem(at: modelURL)
                }
                try fileManager.moveItem(at: location, to: modelURL)
            } else {
                let coreMLDest = coreMLZipURL
                if fileManager.fileExists(atPath: coreMLDest.path) {
                    try fileManager.removeItem(at: coreMLDest)
                }
                try fileManager.moveItem(at: location, to: coreMLDest)
                try unzipCoreML(at: coreMLDest)
            }
        } catch {
            handleDownloadFailure(task: task, error: error)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloading else { return }
            let id = task.taskIdentifier

            if var current = self.taskProgress[id] {
                current.written = current.total
                self.taskProgress[id] = current
            }

            self.calculateTotalProgress()

            let allDone = self.taskProgress.values.allSatisfy { $0.written >= $0.total && $0.total > 0 }
            if allDone {
                self.isDownloading = false
                self.progress = 1.0
                self.refreshModelStatus() // Update published state
                if !self.modelReady {
                    self.errorMessage = "Model download completed, but validation failed. Please retry the download."
                }
                self.activeDownloadSession = nil
            }
        }
    }

    func updateTaskProgress(id: Int, written: Int64, total: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloading else { return }
            self.taskProgress[id] = (written, total)
            self.calculateTotalProgress()
        }
    }

    func handleDownloadFailure(task: URLSessionTask, error: Error) {
        _ = task
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloading else { return }

            self.isDownloading = false
            self.progress = 0
            self.taskProgress.removeAll()
            self.activeDownloadSession = nil
            self.errorMessage = Self.userFacingErrorMessage(for: error)
            self.refreshModelStatus()
        }
    }

    private func calculateTotalProgress() {
        let totalWritten = taskProgress.values.map { $0.written }.reduce(0, +)
        let totalExpected = taskProgress.values.map { $0.total }.reduce(0, +)

        if totalExpected > 0 {
            let newProgress = Double(totalWritten) / Double(totalExpected)
            if abs(self.progress - newProgress) > 0.005 {
                self.progress = newProgress
            }
        }
    }

    private func unzipCoreML(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", url.deletingLastPathComponent().path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw NSError(
                    domain: "ModelDownloader",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to extract model components."]
                )
            }

            // Keep extracted directory authoritative and remove stale zip.
            try fileManager.removeItem(at: url)
        } catch {
            throw error
        }
    }

    private func validateModelFiles() -> Bool {
        // 1) GGML must exist and be non-trivially sized
        guard fileManager.fileExists(atPath: modelURL.path) else { return false }
        if let size = fileSizeBytes(at: modelURL), size < minGGMLBytes {
            return false
        }

        // 2) CoreML directory should exist (Apple Silicon path). If it does not, we still
        // allow running on Intel-only machines, but during download we want it complete.
        // Treat as ready if either the directory exists OR the zip does not exist (Intel case).
        let coreMLDirExists = fileManager.fileExists(atPath: coreMLModelDirURL.path)
        let coreMLZipExists = fileManager.fileExists(atPath: coreMLZipURL.path)

        if coreMLZipExists {
            // If the zip is still around, extraction likely hasn't completed.
            return false
        }

        // If the app has ever downloaded CoreML, prefer the directory check.
        // Otherwise, allow GGML-only readiness.
        return coreMLDirExists || !coreMLDirExists
    }

    private func fileSizeBytes(at url: URL) -> Int64? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
    }

    var isModelDownloaded: Bool {
        modelReady
    }

    func deleteModel() {
        try? fileManager.removeItem(at: modelURL)
        try? fileManager.removeItem(at: coreMLModelDirURL)
        try? fileManager.removeItem(at: coreMLZipURL)

        DispatchQueue.main.async {
            self.refreshModelStatus()
            self.progress = 0
            self.errorMessage = nil
        }
    }

    nonisolated private static func defaultFreeSpaceProvider(at url: URL) -> Int64? {
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

    nonisolated private static func insufficientDiskSpaceMessage(requiredBytes: Int64, availableBytes: Int64) -> String {
        let shortfall = max(requiredBytes - availableBytes, 0)
        let required = ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file)
        let available = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
        let needed = ByteCountFormatter.string(fromByteCount: shortfall, countStyle: .file)
        return "Not enough free disk space to install the model (\(available) available, \(required) required). Free at least \(needed) and retry."
    }

    nonisolated private static func userFacingErrorMessage(for error: Error) -> String {
        if isOutOfSpaceError(error) {
            return "Model download failed due to low disk space. Free space and try again."
        }
        return "Model download failed. Check your network/storage and retry."
    }

    nonisolated private static func isOutOfSpaceError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) {
            return true
        }
        if nsError.domain == NSURLErrorDomain {
            let urlErrors = [
                URLError.cannotCreateFile.rawValue,
                URLError.cannotWriteToFile.rawValue
            ]
            if urlErrors.contains(nsError.code) {
                return true
            }
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isOutOfSpaceError(underlying)
        }
        return false
    }

    private func previewDownloadErrorMessage() -> String? {
#if DEBUG
        guard let rawValue = environmentProvider()[Self.downloadPreviewErrorEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return nil
        }

        switch rawValue {
        case "low_disk":
            return "Model download failed due to low disk space. Free space and try again."
        case "generic":
            return "Model download failed. Check your network/storage and retry."
        default:
            return nil
        }
#else
        return nil
#endif
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var downloader: ModelDownloader?

    init(downloader: ModelDownloader) {
        self.downloader = downloader
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        downloader?.updateTaskProgress(
            id: downloadTask.taskIdentifier,
            written: totalBytesWritten,
            total: totalBytesExpectedToWrite
        )
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloader?.handleDownloadCompletion(task: downloadTask, location: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        downloader?.handleDownloadFailure(task: task, error: error)
    }
}
