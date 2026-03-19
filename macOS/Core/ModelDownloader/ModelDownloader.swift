import Foundation
import Combine
import Darwin

class ModelDownloader: ObservableObject {
    typealias SessionFactory = (URLSessionDownloadDelegate) -> ModelDownloadSessioning
    typealias FreeSpaceProvider = (URL) -> Int64?
    typealias EnvironmentProvider = () -> [String: String]

    static let shared = ModelDownloader()

    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var modelReady: Bool = false
    @Published var errorMessage: String?

    var taskProgress: [Int: (written: Int64, total: Int64)] = [:]
    let fileManager: FileManager
    let modelURLProvider: () -> URL
    let makeDownloadSession: SessionFactory
    let freeSpaceProvider: FreeSpaceProvider
    let environmentProvider: EnvironmentProvider
    let requiredDownloadBytes: Int64
    var activeDownloadSession: ModelDownloadSessioning?

    // Integrity thresholds (hardening only). These are intentionally conservative.
    let minGGMLBytes: Int64
    static let defaultRequiredDownloadBytes: Int64 = 220_000_000
    private static let downloadPreviewErrorEnvironmentKey = "KVX_MODEL_DOWNLOAD_PREVIEW_ERROR"

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

    var coreMLZipURL: URL {
        modelURL.deletingPathExtension().appendingPathExtension("encoder.mlmodelc.zip")
    }

    var coreMLModelDirURL: URL {
        modelURL.deletingPathExtension().appendingPathExtension("encoder.mlmodelc")
    }

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

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

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
