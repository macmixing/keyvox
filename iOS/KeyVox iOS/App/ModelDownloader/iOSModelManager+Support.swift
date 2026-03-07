import CryptoKit
import Foundation
import ZIPFoundation

extension iOSModelManager {
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

    func writeManifest(_ manifest: iOSModelInstallManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try removeItemIfExists(at: url)
        try data.write(to: url, options: .atomic)
        Self.debugLog("writeManifest: wrote \(url.path)")
    }

    func readManifest(from url: URL) throws -> iOSModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(iOSModelInstallManifest.self, from: data)
    }

    nonisolated static func defaultDownload(from url: URL) async throws -> URL {
        let (downloadURL, _) = try await URLSession.shared.download(from: url)
        return downloadURL
    }

    nonisolated static func defaultUnzip(zipURL: URL, destinationDirectory: URL, fileManager: FileManager) async throws {
        let archive = try Archive(url: zipURL, accessMode: .read)

        for entry in archive {
            let destinationURL = destinationDirectory.appendingPathComponent(entry.path)
            let parentDirectory = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }
            _ = try archive.extract(entry, to: destinationURL)
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

    nonisolated static func sha256Hex(forFileAt url: URL) throws -> String {
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

    nonisolated static func directoryDigestHex(at rootURL: URL, fileManager: FileManager) throws -> String {
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
        var hasher = SHA256()
        for fileURL in fileURLs {
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            hasher.update(data: Data(relativePath.utf8))
            hasher.update(data: Data([0]))
            let fileHash = try sha256Hex(forFileAt: fileURL)
            debugLog("directoryDigestHex: \(relativePath) -> \(fileHash)")
            hasher.update(data: Data(fileHash.utf8))
            hasher.update(data: Data([0]))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func debugLog(_ message: String) {
#if DEBUG
        print("[iOSModelManager] \(message)")
#endif
    }
}

struct ResolvedPaths {
    let modelsDirectory: URL
    let ggmlModelURL: URL
    let coreMLZipURL: URL
    let coreMLDirectoryURL: URL
    let manifestURL: URL
}

enum InstallValidationResult: Equatable {
    case notInstalled
    case ready
    case failed(message: String)

    var debugDescription: String {
        switch self {
        case .notInstalled:
            return "notInstalled"
        case .ready:
            return "ready"
        case .failed(let message):
            return "failed(\(message))"
        }
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
