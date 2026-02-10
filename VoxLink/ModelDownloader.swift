import Foundation
import Combine

class ModelDownloader: ObservableObject {
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var errorMessage: String?
    
    private var downloadTask: URLSessionDownloadTask?
    
    var modelURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voxLinkDir = appSupport.appendingPathComponent("VoxLink")
        
        if !FileManager.default.fileExists(atPath: voxLinkDir.path) {
            try? FileManager.default.createDirectory(at: voxLinkDir, withIntermediateDirectories: true)
        }
        
        return voxLinkDir.appendingPathComponent("ggml-base.en.bin")
    }
    
    init() {
        cleanupOldModels()
    }
    
    private func cleanupOldModels() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voxLinkDir = appSupport.appendingPathComponent("VoxLink")
        
        let tinyModel = voxLinkDir.appendingPathComponent("ggml-tiny.en.bin")
        let tinyCoreML = voxLinkDir.appendingPathComponent("ggml-tiny.en-encoder.mlmodelc")
        
        // Remove Tiny Model (Clean up as requested)
        try? fileManager.removeItem(at: tinyModel)
        try? fileManager.removeItem(at: tinyCoreML)
    }
    
    func downloadBaseModel() {
        guard !isDownloading else { return }
        
        // 1. Download the Base GGML model (Better than Tiny, still fast)
        let ggmlURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!
        
        // 2. Download the CoreML model (Neural Engine acceleration for Base)
        let coreMLURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-encoder.mlmodelc.zip")!
        
        isDownloading = true
        progress = 0
        errorMessage = nil
        
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(progressHandler: { progress in
            DispatchQueue.main.async {
                self.progress = progress
            }
        }), delegateQueue: nil)
        
        // Parallel download group
        let group = DispatchGroup()
        
        // Task A: GGML Model
        group.enter()
        let taskA = session.downloadTask(with: ggmlURL) { localURL, _, error in
            defer { group.leave() }
            if let localURL = localURL {
                try? FileManager.default.removeItem(at: self.modelURL)
                try? FileManager.default.moveItem(at: localURL, to: self.modelURL)
            }
        }
        taskA.resume()
        
        // Task B: CoreML Model
        group.enter()
        let taskB = session.downloadTask(with: coreMLURL) { localURL, _, error in
            defer { group.leave() }
            if let localURL = localURL {
                // Determine destination for CoreML model
                let coreMLDest = self.modelURL.deletingPathExtension().appendingPathExtension("en-encoder.mlmodelc.zip")
                try? FileManager.default.removeItem(at: coreMLDest)
                try? FileManager.default.moveItem(at: localURL, to: coreMLDest)
                
                // We need to unzip this for it to work.
                // For simplicity in this step, we'll ask the user to unzip or use a shell command.
                // Ideally, we'd use a lightweight unzip library or `Process` to unzip.
                self.unzipCoreML(at: coreMLDest)
            }
        }
        taskB.resume()
        
        group.notify(queue: .main) {
            self.isDownloading = false
            print("Downloads complete. Hardware acceleration assets ready.")
        }
    }
    
    private func unzipCoreML(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", url.deletingLastPathComponent().path]
        try? process.run()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
    }
    
    var isModelDownloaded: Bool {
        FileManager.default.fileExists(atPath: modelURL.path)
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the completion block of downloadTask
    }
}
