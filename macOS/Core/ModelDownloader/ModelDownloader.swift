import Foundation
import Combine
import Darwin

class ModelDownloader: ObservableObject {
    typealias SessionFactory = (URLSessionDownloadDelegate) -> ModelDownloadSessioning
    typealias FreeSpaceProvider = (URL) -> Int64?
    typealias EnvironmentProvider = () -> [String: String]
    typealias PostInstallPreparation = (DictationModelID) async throws -> Void

    struct ActiveDownload {
        let modelID: DictationModelID
        let descriptor: DictationModelDescriptor
    }

    static let shared = ModelDownloader()

    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var modelReady: Bool = false
    @Published var errorMessage: String?
    @Published var parakeetModelReady: Bool = false
    @Published private(set) var modelStates: [DictationModelID: DictationModelInstallState]

    var taskProgress: [Int: (written: Int64, total: Int64)] = [:]
    var taskProgressSnapshot: [Int: (written: Int64, total: Int64)] { taskProgress }

    let fileManager: FileManager
    let modelURLProvider: () -> URL
    let makeDownloadSession: SessionFactory
    let freeSpaceProvider: FreeSpaceProvider
    let environmentProvider: EnvironmentProvider
    let requiredDownloadBytes: Int64
    let minGGMLBytes: Int64
    let modelLocator: InstalledDictationModelLocator
    var postInstallPreparation: PostInstallPreparation = { _ in }

    var activeDownloadSession: ModelDownloadSessioning?
    var activeDownload: ActiveDownload?
    var artifactsByTaskID: [Int: DictationModelArtifact] = [:]
    var completedTaskIDs: Set<Int> = []

    static let defaultRequiredDownloadBytes: Int64 = 220_000_000
    private static let downloadPreviewErrorEnvironmentKey = "KVX_MODEL_DOWNLOAD_PREVIEW_ERROR"

    var modelURL: URL {
        let resolved = modelURLProvider()
        let modelsDir = resolved.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        return resolved
    }

    var coreMLZipURL: URL {
        modelURL
            .deletingLastPathComponent()
            .appendingPathComponent("ggml-base-encoder.mlmodelc.zip", isDirectory: false)
    }

    var coreMLModelDirURL: URL {
        modelURL
            .deletingLastPathComponent()
            .appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
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
        self.modelStates = Dictionary(
            uniqueKeysWithValues: DictationModelID.allCases.map { ($0, DictationModelInstallState()) }
        )

        let appSupportRootURL: URL
        if let modelURLOverride {
            let whisperDirectoryURL = modelURLOverride.deletingLastPathComponent()
            let modelsRootURL = whisperDirectoryURL.deletingLastPathComponent()
            appSupportRootURL = modelsRootURL.deletingLastPathComponent()
            self.modelURLProvider = { modelURLOverride }
        } else {
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            appSupportRootURL = appSupportURL.appendingPathComponent("KeyVox", isDirectory: true)
            self.modelURLProvider = {
                appSupportRootURL
                    .appendingPathComponent("Models", isDirectory: true)
                    .appendingPathComponent("whisper", isDirectory: true)
                    .appendingPathComponent("ggml-base.bin", isDirectory: false)
            }
        }

        self.modelLocator = InstalledDictationModelLocator(
            fileManager: fileManager,
            appSupportRootURL: appSupportRootURL
        )
        try? self.modelLocator.migrateLegacyWhisperInstallIfNeeded()

        if refreshOnInit {
            refreshModelStatus()
        } else {
            syncLegacyWhisperState()
        }
    }

    deinit {}

    var isModelDownloaded: Bool {
        state(for: .whisperBase).isReady
    }

    func state(for modelID: DictationModelID) -> DictationModelInstallState {
        modelStates[modelID] ?? DictationModelInstallState()
    }

    func isModelReady(for modelID: DictationModelID) -> Bool {
        state(for: modelID).isReady
    }

    func isDownloading(for modelID: DictationModelID) -> Bool {
        state(for: modelID).isDownloading
    }

    func progress(for modelID: DictationModelID) -> Double {
        state(for: modelID).progress
    }

    func errorMessage(for modelID: DictationModelID) -> String? {
        state(for: modelID).errorMessage
    }

    func refreshModelStatus() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshModelStatus()
            }
            return
        }

        updateReadyState(validateWhisperModelFiles(), for: .whisperBase)
        updateReadyState(validateStrictManifestModel(.parakeetTdtV3), for: .parakeetTdtV3)
        syncLegacyWhisperState()
    }

    func downloadBaseModel() {
        downloadModel(withID: .whisperBase)
    }

    func downloadModel(withID modelID: DictationModelID) {
        guard activeDownload == nil else { return }

        let descriptor = modelLocator.descriptor(for: modelID)
        if let previewErrorMessage = previewDownloadErrorMessage() {
            updateDownloadState(
                DictationModelInstallState(
                    isReady: isModelReady(for: modelID),
                    isDownloading: false,
                    progress: 0,
                    errorMessage: previewErrorMessage
                ),
                for: modelID
            )
            syncLegacyWhisperState()
            return
        }

        if let availableBytes = freeSpaceProvider(modelLocator.modelsRootURL),
           availableBytes < descriptor.requiredDownloadBytes {
            updateDownloadState(
                DictationModelInstallState(
                    isReady: isModelReady(for: modelID),
                    isDownloading: false,
                    progress: 0,
                    errorMessage: Self.insufficientDiskSpaceMessage(
                        requiredBytes: descriptor.requiredDownloadBytes,
                        availableBytes: availableBytes
                    )
                ),
                for: modelID
            )
            syncLegacyWhisperState()
            return
        }

        activeDownload = ActiveDownload(modelID: modelID, descriptor: descriptor)
        taskProgress.removeAll()
        artifactsByTaskID.removeAll()
        completedTaskIDs.removeAll()
        updateDownloadState(
            DictationModelInstallState(
                isReady: isModelReady(for: modelID),
                isDownloading: true,
                progress: 0,
                errorMessage: nil
            ),
            for: modelID
        )

        let delegate = DownloadDelegate(downloader: self)
        let session = makeDownloadSession(delegate)
        activeDownloadSession = session
        debugLog("Starting download for \(modelID.rawValue) with \(descriptor.artifacts.count) artifacts.")

        for artifact in descriptor.artifacts {
            let task = session.downloadTask(with: artifact.remoteURL)
            artifactsByTaskID[task.taskIdentifier] = artifact
            taskProgress[task.taskIdentifier] = (0, max(artifact.progressTotalBytes, 1))
            debugLog("Queued task \(task.taskIdentifier) for \(artifact.relativePath)")
            task.resume()
        }

        syncLegacyWhisperState()
    }

    func deleteModel() {
        deleteModel(withID: .whisperBase)
    }

    func deleteModel(withID modelID: DictationModelID) {
        let descriptor = modelLocator.descriptor(for: modelID)

        switch descriptor.installLayout {
        case .legacyWhisperBase:
            try? fileManager.removeItem(at: modelLocator.installRootURL(for: modelID))
            try? fileManager.removeItem(at: coreMLModelDirURL)
            try? fileManager.removeItem(at: coreMLZipURL)
        case .subdirectory:
            try? fileManager.removeItem(at: modelLocator.installRootURL(for: modelID))
            try? fileManager.removeItem(at: modelLocator.stagingRootURL(for: modelID))
        }

        let resetState = {
            self.updateDownloadState(DictationModelInstallState(), for: modelID)
            self.refreshModelStatus()
        }

        if Thread.isMainThread {
            resetState()
        } else {
            DispatchQueue.main.async(execute: resetState)
        }
    }

    func updateReadyState(_ isReady: Bool, for modelID: DictationModelID) {
        // These helpers are intentionally fire-and-forget. Callers that need a strict
        // mutation sequence should dispatch the whole sequence to the main queue first.
        let apply = {
            var state = self.state(for: modelID)
            state.isReady = isReady
            self.modelStates[modelID] = state
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func updateDownloadState(_ state: DictationModelInstallState, for modelID: DictationModelID) {
        let apply = {
            self.modelStates[modelID] = state
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func syncLegacyWhisperState() {
        let apply = {
            let whisperState = self.state(for: .whisperBase)
            self.modelReady = whisperState.isReady
            self.isDownloading = whisperState.isDownloading
            self.progress = whisperState.progress
            self.errorMessage = whisperState.errorMessage
            self.parakeetModelReady = self.state(for: .parakeetTdtV3).isReady
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func debugLog(_ message: String) {
#if DEBUG
        print("[ModelDownloader] \(message)")
#endif
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
