import Foundation

struct AppUpdateArchiveExtractor {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func extract(zipURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let stderrPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, destinationURL.path]
        process.standardError = stderrPipe
        try process.run()

        let deadline = Date().addingTimeInterval(30)
        var didTimeOut = false
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        if process.isRunning {
            didTimeOut = true
            process.terminate()
        }

        process.waitUntilExit()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrOutput = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !didTimeOut, process.terminationStatus == 0 else {
            #if DEBUG
            let diagnostic = didTimeOut ? "ditto timed out after 30s" : (stderrOutput?.isEmpty == false ? stderrOutput! : "ditto exited with status \(process.terminationStatus)")
            print("[AppUpdateArchiveExtractor] \(diagnostic)")
            #endif
            throw AppUpdateError.extractionFailed
        }
    }
}
