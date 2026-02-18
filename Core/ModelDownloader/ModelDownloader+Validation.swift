import Foundation
import Darwin

extension ModelDownloader {
    func validateModelFiles() -> Bool {
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

    nonisolated static func insufficientDiskSpaceMessage(requiredBytes: Int64, availableBytes: Int64) -> String {
        let shortfall = max(requiredBytes - availableBytes, 0)
        let required = ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file)
        let available = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
        let needed = ByteCountFormatter.string(fromByteCount: shortfall, countStyle: .file)
        return "Not enough free disk space to install the model (\(available) available, \(required) required). Free at least \(needed) and retry."
    }

    nonisolated static func userFacingErrorMessage(for error: Error) -> String {
        if isOutOfSpaceError(error) {
            return "Model download failed due to low disk space. Free space and try again."
        }
        return "Model download failed. Check your network/storage and retry."
    }

    nonisolated static func isOutOfSpaceError(_ error: Error) -> Bool {
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
}
