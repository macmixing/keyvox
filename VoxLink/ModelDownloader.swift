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
        
        return voxLinkDir.appendingPathComponent("ggml-tiny.en.bin")
    }
    
    func downloadBaseModel() {
        guard !isDownloading else { return }
        
        let sourceURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin")!
        
        isDownloading = true
        progress = 0
        errorMessage = nil
        
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(progressHandler: { progress in
            DispatchQueue.main.async {
                self.progress = progress
            }
        }), delegateQueue: nil)
        
        downloadTask = session.downloadTask(with: sourceURL) { localURL, response, error in
            DispatchQueue.main.async {
                self.isDownloading = false
                
                if let error = error {
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                    return
                }
                
                guard let localURL = localURL else {
                    self.errorMessage = "Download failed: No local URL."
                    return
                }
                
                do {
                    if FileManager.default.fileExists(atPath: self.modelURL.path) {
                        try FileManager.default.removeItem(at: self.modelURL)
                    }
                    try FileManager.default.moveItem(at: localURL, to: self.modelURL)
                    print("Model downloaded to: \(self.modelURL.path)")
                } catch {
                    self.errorMessage = "Failed to copy model: \(error.localizedDescription)"
                }
            }
        }
        
        downloadTask?.resume()
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
