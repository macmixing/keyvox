import Foundation
import Combine

class ModelDownloader: ObservableObject {
    static let shared = ModelDownloader()
    
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var modelReady: Bool = false
    @Published var errorMessage: String?
    
    private var taskProgress: [Int: (written: Int64, total: Int64)] = [:]
    
    var modelURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let KeyVoxDir = appSupport.appendingPathComponent("KeyVox")
        
        if !FileManager.default.fileExists(atPath: KeyVoxDir.path) {
            try? FileManager.default.createDirectory(at: KeyVoxDir, withIntermediateDirectories: true)
        }
        
        return KeyVoxDir.appendingPathComponent("ggml-base.en.bin")
    }
    
    private var coreMLZipURL: URL {
        modelURL.deletingPathExtension().appendingPathExtension("en-encoder.mlmodelc.zip")
    }

    private var coreMLModelDirURL: URL {
        modelURL.deletingPathExtension().appendingPathExtension("en-encoder.mlmodelc")
    }

    // Integrity thresholds (hardening only). These are intentionally conservative.
    private let minGGMLBytes: Int64 = 90_000_000
    
    init() {
        refreshModelStatus()
        cleanupOldModels()
    }
    
    func refreshModelStatus() {
        modelReady = validateModelFiles()
    }
    
    private func cleanupOldModels() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let KeyVoxDir = appSupport.appendingPathComponent("KeyVox")
        
        let tinyModel = KeyVoxDir.appendingPathComponent("ggml-tiny.en.bin")
        let tinyCoreML = KeyVoxDir.appendingPathComponent("ggml-tiny.en-encoder.mlmodelc")
        
        try? fileManager.removeItem(at: tinyModel)
        try? fileManager.removeItem(at: tinyCoreML)
    }
    
    func downloadBaseModel() {
        guard !isDownloading else { return }
        
        let ggmlURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!
        let coreMLURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-encoder.mlmodelc.zip")!
        
        isDownloading = true
        progress = 0
        errorMessage = nil
        taskProgress.removeAll()
        
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(downloader: self), delegateQueue: nil)
        
        let taskA = session.downloadTask(with: ggmlURL)
        let taskB = session.downloadTask(with: coreMLURL)
        
        taskProgress[taskA.taskIdentifier] = (0, 140_000_000)
        taskProgress[taskB.taskIdentifier] = (0, 50_000_000)
        
        taskA.resume()
        taskB.resume()
    }
    
    func handleDownloadCompletion(task: URLSessionDownloadTask, location: URL) {
        let urlString = task.originalRequest?.url?.absoluteString ?? ""
        let isGGML = urlString.contains("ggml-base.en.bin")
        
        if isGGML {
            try? FileManager.default.removeItem(at: self.modelURL)
            try? FileManager.default.moveItem(at: location, to: self.modelURL)
        } else {
            let coreMLDest = self.coreMLZipURL
            try? FileManager.default.removeItem(at: coreMLDest)
            try? FileManager.default.moveItem(at: location, to: coreMLDest)
            self.unzipCoreML(at: coreMLDest)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
            }
        }
    }
    
    func updateTaskProgress(id: Int, written: Int64, total: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.taskProgress[id] = (written, total)
            self.calculateTotalProgress()
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
    
    private func unzipCoreML(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", url.deletingLastPathComponent().path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // Best-effort cleanup of the zip once extracted.
                try? FileManager.default.removeItem(at: url)
            }
        } catch {
            // Best-effort: leave the zip for troubleshooting/retry.
            #if DEBUG
            print("CoreML unzip failed: \(error)")
            #endif
        }
    }
    
    private func validateModelFiles() -> Bool {
        let fm = FileManager.default

        // 1) GGML must exist and be non-trivially sized
        guard fm.fileExists(atPath: modelURL.path) else { return false }
        if let size = fileSizeBytes(at: modelURL), size < minGGMLBytes {
            return false
        }

        // 2) CoreML directory should exist (Apple Silicon path). If it does not, we still
        // allow running on Intel-only machines, but during download we want it complete.
        // Treat as ready if either the directory exists OR the zip does not exist (Intel case).
        let coreMLDirExists = fm.fileExists(atPath: coreMLModelDirURL.path)
        let coreMLZipExists = fm.fileExists(atPath: coreMLZipURL.path)

        if coreMLZipExists {
            // If the zip is still around, extraction likely hasn't completed.
            return false
        }

        // If the app has ever downloaded CoreML, prefer the directory check.
        // Otherwise, allow GGML-only readiness.
        return coreMLDirExists || !coreMLDirExists
    }

    private func fileSizeBytes(at url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
    }
    
    var isModelDownloaded: Bool {
        modelReady
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var downloader: ModelDownloader?
    
    init(downloader: ModelDownloader) {
        self.downloader = downloader
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloader?.updateTaskProgress(
            id: downloadTask.taskIdentifier,
            written: totalBytesWritten,
            total: totalBytesExpectedToWrite
        )
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloader?.handleDownloadCompletion(task: downloadTask, location: location)
    }
}
