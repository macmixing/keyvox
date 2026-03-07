import Combine
import CryptoKit
import Foundation
import KeyVoxCore
import ZIPFoundation

@MainActor
protocol iOSWhisperModelLifecycle: AnyObject {
    func warmup()
    func unloadModel()
}

extension WhisperService: iOSWhisperModelLifecycle {}

@MainActor
final class iOSModelManager: ObservableObject {
    typealias DownloadClosure = @Sendable (URL) async throws -> URL
    typealias UnzipClosure = @Sendable (URL, URL, FileManager) async throws -> Void
    typealias FreeSpaceProvider = @Sendable (URL) -> Int64?

    @Published private(set) var installState: iOSModelInstallState = .notInstalled
    @Published private(set) var modelReady = false
    @Published private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let whisperService: any iOSWhisperModelLifecycle
    private let modelsDirectoryProvider: () -> URL?
    private let ggmlModelURLProvider: () -> URL?
    private let coreMLZipURLProvider: () -> URL?
    private let coreMLDirectoryURLProvider: () -> URL?
    private let manifestURLProvider: () -> URL?
    private let download: DownloadClosure
    private let unzip: UnzipClosure
    private let freeSpaceProvider: FreeSpaceProvider
    private let minGGMLBytes: Int64
    private let requiredDownloadBytes: Int64
    private let expectedGGMLSHA256: String
    private let expectedCoreMLZipSHA256: String

    private var currentDownloadTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        whisperService: any iOSWhisperModelLifecycle,
        modelsDirectoryProvider: @escaping () -> URL? = { iOSSharedPaths.modelsDirectoryURL() },
        ggmlModelURLProvider: @escaping () -> URL? = { iOSSharedPaths.modelFileURL() },
        coreMLZipURLProvider: @escaping () -> URL? = { iOSSharedPaths.coreMLEncoderZipURL() },
        coreMLDirectoryURLProvider: @escaping () -> URL? = { iOSSharedPaths.coreMLEncoderDirectoryURL() },
        manifestURLProvider: @escaping () -> URL? = { iOSSharedPaths.modelInstallManifestURL() },
        minGGMLBytes: Int64 = iOSModelArtifacts.minGGMLBytes,
        requiredDownloadBytes: Int64 = 220_000_000,
        expectedGGMLSHA256: String = iOSModelArtifacts.ggmlBaseSHA256,
        expectedCoreMLZipSHA256: String = iOSModelArtifacts.coreMLZipSHA256,
        freeSpaceProvider: @escaping FreeSpaceProvider = defaultFreeSpaceProvider(at:),
        download: DownloadClosure? = nil,
        unzip: UnzipClosure? = nil
    ) {
        self.fileManager = fileManager
        self.whisperService = whisperService
        self.modelsDirectoryProvider = modelsDirectoryProvider
        self.ggmlModelURLProvider = ggmlModelURLProvider
        self.coreMLZipURLProvider = coreMLZipURLProvider
        self.coreMLDirectoryURLProvider = coreMLDirectoryURLProvider
        self.manifestURLProvider = manifestURLProvider
        self.minGGMLBytes = minGGMLBytes
        self.requiredDownloadBytes = requiredDownloadBytes
        self.expectedGGMLSHA256 = expectedGGMLSHA256
        self.expectedCoreMLZipSHA256 = expectedCoreMLZipSHA256
        self.freeSpaceProvider = freeSpaceProvider
        self.download = download ?? Self.defaultDownload(from:)
        self.unzip = unzip ?? Self.defaultUnzip(zipURL:destinationDirectory:fileManager:)

        Self.debugLog("Initialized model manager.")
        refreshStatus()
    }

    func refreshStatus() {
        guard let paths = resolvedPaths() else {
            Self.debugLog("refreshStatus: App Group container unavailable.")
            modelReady = false
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            return
        }

        let validation = validateInstall(paths: paths)
        Self.debugLog("""
        refreshStatus:
          modelsDirectory=\(paths.modelsDirectory.path)
          ggml=\(paths.ggmlModelURL.path)
          coreMLDir=\(paths.coreMLDirectoryURL.path)
          coreMLZip=\(paths.coreMLZipURL.path)
          manifest=\(paths.manifestURL.path)
          result=\(validation.debugDescription)
        """)

        switch validation {
        case .ready:
            modelReady = true
            installState = .ready
            errorMessage = nil
        case .notInstalled:
            modelReady = false
            installState = .notInstalled
            errorMessage = nil
        case .failed(let message):
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
        }
    }

    func downloadModel() {
        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            await self?.performDownloadModel()
        }
    }

    func deleteModel() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        performDeleteModel()
    }

    func repairModelIfNeeded() {
        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            await self?.performRepairModelIfNeeded()
        }
    }

    func performDownloadModel() async {
        defer { currentDownloadTask = nil }
        errorMessage = nil

        guard let paths = resolvedPaths() else {
            Self.debugLog("performDownloadModel: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        do {
            Self.debugLog("""
            performDownloadModel: starting
              modelsDirectory=\(paths.modelsDirectory.path)
              ggml=\(paths.ggmlModelURL.path)
              coreMLZip=\(paths.coreMLZipURL.path)
              coreMLDir=\(paths.coreMLDirectoryURL.path)
              manifest=\(paths.manifestURL.path)
            """)
            try ensureModelsDirectoryExists(paths.modelsDirectory)
            try ensureEnoughDiskSpace(in: paths.modelsDirectory)

            installState = .downloading(progress: 0.05)
            Self.debugLog("performDownloadModel: downloading GGML + Core ML archive.")
            async let ggmlDownload = download(iOSModelDownloadURLs.ggmlBase)
            async let coreMLZipDownload = download(iOSModelDownloadURLs.coreMLZip)

            let ggmlTempURL = try await ggmlDownload
            installState = .downloading(progress: 0.5)
            let coreMLZipTempURL = try await coreMLZipDownload
            installState = .downloading(progress: 0.85)
            Self.debugLog("""
            performDownloadModel: downloads finished
              ggmlTemp=\(ggmlTempURL.path)
              coreMLZipTemp=\(coreMLZipTempURL.path)
            """)

            try moveDownloadedFile(from: ggmlTempURL, to: paths.ggmlModelURL)
            try moveDownloadedFile(from: coreMLZipTempURL, to: paths.coreMLZipURL)
            Self.debugLog("performDownloadModel: moved downloaded files into Models/.")

            let ggmlSHA256 = try Self.sha256Hex(forFileAt: paths.ggmlModelURL)
            Self.debugLog("""
            performDownloadModel: ggml hash
              actual=\(ggmlSHA256)
              expected=\(expectedGGMLSHA256)
            """)
            guard ggmlSHA256 == expectedGGMLSHA256 else {
                throw ModelInstallError.integrityCheckFailed("ggml-base.bin did not match the expected SHA-256.")
            }
            let coreMLZipSHA256 = try Self.sha256Hex(forFileAt: paths.coreMLZipURL)
            Self.debugLog("""
            performDownloadModel: coreml zip hash
              actual=\(coreMLZipSHA256)
              expected=\(expectedCoreMLZipSHA256)
            """)
            guard coreMLZipSHA256 == expectedCoreMLZipSHA256 else {
                throw ModelInstallError.integrityCheckFailed("The Core ML archive did not match the expected SHA-256.")
            }

            installState = .installing
            Self.debugLog("performDownloadModel: extracting Core ML archive.")
            try await unzip(paths.coreMLZipURL, paths.modelsDirectory, fileManager)
            let coreMLDirectoryDigest = try Self.directoryDigestHex(at: paths.coreMLDirectoryURL, fileManager: fileManager)
            if let structureIssue = Self.validateExtractedCoreMLBundle(at: paths.coreMLDirectoryURL, fileManager: fileManager) {
                throw ModelInstallError.integrityCheckFailed(structureIssue)
            }
            Self.debugLog("""
            performDownloadModel: coreml directory digest
              actual=\(coreMLDirectoryDigest)
            """)
            try removeItemIfExists(at: paths.coreMLZipURL)
            Self.debugLog("performDownloadModel: removed Core ML zip after successful extraction.")

            let manifest = iOSModelInstallManifest(
                version: iOSModelInstallManifest.currentVersion,
                ggmlSHA256: ggmlSHA256,
                coreMLZipSHA256: coreMLZipSHA256
            )
            try writeManifest(manifest, to: paths.manifestURL)
            Self.debugLog("performDownloadModel: wrote install manifest.")

            let validation = validateInstall(paths: paths)
            Self.debugLog("performDownloadModel: post-install validation = \(validation.debugDescription)")
            switch validation {
            case .ready:
                whisperService.unloadModel()
                whisperService.warmup()
                modelReady = true
                installState = .ready
                errorMessage = nil
                Self.debugLog("performDownloadModel: install complete and whisper warmed.")
            case .notInstalled:
                modelReady = false
                installState = .failed(message: "Model install is incomplete.")
                errorMessage = "Model install is incomplete."
                Self.debugLog("performDownloadModel: validation unexpectedly returned notInstalled.")
            case .failed(let message):
                modelReady = false
                installState = .failed(message: message)
                errorMessage = message
                Self.debugLog("performDownloadModel: validation failed after install: \(message)")
            }
        } catch {
            Self.debugLog("performDownloadModel: failed with error: \(Self.userFacingErrorMessage(for: error))")
            modelReady = false
            installState = .failed(message: Self.userFacingErrorMessage(for: error))
            errorMessage = Self.userFacingErrorMessage(for: error)
            iOSModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
    }

    func performDeleteModel() {
        guard let paths = resolvedPaths() else {
            Self.debugLog("performDeleteModel: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        Self.debugLog("""
        performDeleteModel:
          ggmlExists=\(fileManager.fileExists(atPath: paths.ggmlModelURL.path))
          coreMLDirExists=\(fileManager.fileExists(atPath: paths.coreMLDirectoryURL.path))
          coreMLZipExists=\(fileManager.fileExists(atPath: paths.coreMLZipURL.path))
          manifestExists=\(fileManager.fileExists(atPath: paths.manifestURL.path))
        """)
        whisperService.unloadModel()
        try? removeItemIfExists(at: paths.ggmlModelURL)
        try? removeItemIfExists(at: paths.coreMLDirectoryURL)
        try? removeItemIfExists(at: paths.coreMLZipURL)
        try? removeItemIfExists(at: paths.manifestURL)

        refreshStatus()
    }

    func performRepairModelIfNeeded() async {
        defer { currentDownloadTask = nil }
        guard let paths = resolvedPaths() else {
            Self.debugLog("performRepairModelIfNeeded: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        let validation = validateInstall(paths: paths)
        Self.debugLog("performRepairModelIfNeeded: validation = \(validation.debugDescription)")
        switch validation {
        case .ready:
            Self.debugLog("performRepairModelIfNeeded: install already ready, no-op.")
            return
        case .notInstalled, .failed:
            try? removeItemIfExists(at: paths.ggmlModelURL)
            try? removeItemIfExists(at: paths.coreMLDirectoryURL)
            try? removeItemIfExists(at: paths.coreMLZipURL)
            try? removeItemIfExists(at: paths.manifestURL)
            await performDownloadModel()
        }
    }

    private func resolvedPaths() -> ResolvedPaths? {
        guard let modelsDirectory = modelsDirectoryProvider(),
              let ggmlModelURL = ggmlModelURLProvider(),
              let coreMLZipURL = coreMLZipURLProvider(),
              let coreMLDirectoryURL = coreMLDirectoryURLProvider(),
              let manifestURL = manifestURLProvider() else {
            return nil
        }

        return ResolvedPaths(
            modelsDirectory: modelsDirectory,
            ggmlModelURL: ggmlModelURL,
            coreMLZipURL: coreMLZipURL,
            coreMLDirectoryURL: coreMLDirectoryURL,
            manifestURL: manifestURL
        )
    }

    private func ensureModelsDirectoryExists(_ modelsDirectory: URL) throws {
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            Self.debugLog("ensureModelsDirectoryExists: created \(modelsDirectory.path)")
        }
    }

    private func ensureEnoughDiskSpace(in modelsDirectory: URL) throws {
        guard let availableBytes = freeSpaceProvider(modelsDirectory) else { return }
        Self.debugLog("""
        ensureEnoughDiskSpace:
          available=\(availableBytes)
          required=\(requiredDownloadBytes)
        """)
        guard availableBytes >= requiredDownloadBytes else {
            throw ModelInstallError.insufficientDiskSpace(requiredBytes: requiredDownloadBytes, availableBytes: availableBytes)
        }
    }

    private func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        try removeItemIfExists(at: destinationURL)
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        Self.debugLog("moveDownloadedFile: \(sourceURL.lastPathComponent) -> \(destinationURL.path)")
    }

    private func removeItemIfExists(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func validateInstall(paths: ResolvedPaths) -> InstallValidationResult {
        let ggmlExists = fileManager.fileExists(atPath: paths.ggmlModelURL.path)
        let coreMLDirectoryExists = fileManager.fileExists(atPath: paths.coreMLDirectoryURL.path)
        let coreMLZipExists = fileManager.fileExists(atPath: paths.coreMLZipURL.path)
        let manifestExists = fileManager.fileExists(atPath: paths.manifestURL.path)
        let ggmlSize = fileSizeBytes(at: paths.ggmlModelURL)
        Self.debugLog("""
        validateInstall:
          ggmlExists=\(ggmlExists)
          ggmlSize=\(ggmlSize.map(String.init) ?? "nil")
          minGGMLBytes=\(minGGMLBytes)
          coreMLDirectoryExists=\(coreMLDirectoryExists)
          coreMLZipExists=\(coreMLZipExists)
          manifestExists=\(manifestExists)
        """)

        guard ggmlExists || coreMLDirectoryExists || coreMLZipExists || manifestExists else {
            return .notInstalled
        }

        guard ggmlExists else {
            return .failed(message: "Model install is incomplete. Missing ggml-base.bin.")
        }

        guard let ggmlSize, ggmlSize >= minGGMLBytes else {
            return .failed(message: "Model install is incomplete. ggml-base.bin is missing or undersized.")
        }

        guard coreMLDirectoryExists else {
            return .failed(message: "Model install is incomplete. Missing ggml-base-encoder.mlmodelc.")
        }

        guard !coreMLZipExists else {
            return .failed(message: "Model install is incomplete. Core ML zip cleanup did not finish.")
        }

        guard manifestExists else {
            return .failed(message: "Model install is incomplete. Missing install manifest.")
        }

        do {
            let manifest = try readManifest(from: paths.manifestURL)
            Self.debugLog("""
            validateInstall: manifest
              version=\(manifest.version)
              ggmlSHA=\(manifest.ggmlSHA256)
              coreMLZipSHA=\(manifest.coreMLZipSHA256)
            """)
            guard iOSModelInstallManifest.supportedVersions.contains(manifest.version) else {
                return .failed(message: "Model install manifest version is not supported.")
            }
            guard manifest.ggmlSHA256 == expectedGGMLSHA256 else {
                return .failed(message: "Model install manifest does not match the expected GGML artifact.")
            }
            guard manifest.coreMLZipSHA256 == expectedCoreMLZipSHA256 else {
                return .failed(message: "Model install manifest does not match the expected Core ML archive.")
            }
            if let structureIssue = Self.validateExtractedCoreMLBundle(at: paths.coreMLDirectoryURL, fileManager: fileManager) {
                return .failed(message: structureIssue)
            }
        } catch {
            return .failed(message: "Model install manifest is missing or unreadable.")
        }

        return .ready
    }

    private func fileSizeBytes(at url: URL) -> Int64? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
    }

    private func writeManifest(_ manifest: iOSModelInstallManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try removeItemIfExists(at: url)
        try data.write(to: url, options: .atomic)
        Self.debugLog("writeManifest: wrote \(url.path)")
    }

    private func readManifest(from url: URL) throws -> iOSModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(iOSModelInstallManifest.self, from: data)
    }

    nonisolated private static func defaultDownload(from url: URL) async throws -> URL {
        let (downloadURL, _) = try await URLSession.shared.download(from: url)
        return downloadURL
    }

    nonisolated private static func defaultUnzip(zipURL: URL, destinationDirectory: URL, fileManager: FileManager) async throws {
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

    nonisolated private static func userFacingErrorMessage(for error: Error) -> String {
        if let modelError = error as? ModelInstallError {
            return modelError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return "Model download failed due to low disk space. Free space and try again."
        }
        return "Model download failed. Check your network/storage and retry."
    }

    nonisolated private static func sha256Hex(forFileAt url: URL) throws -> String {
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

    nonisolated private static func validateExtractedCoreMLBundle(at rootURL: URL, fileManager: FileManager) -> String? {
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

    nonisolated private static func directoryDigestHex(at rootURL: URL, fileManager: FileManager) throws -> String {
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

    nonisolated private static func debugLog(_ message: String) {
#if DEBUG
        print("[iOSModelManager] \(message)")
#endif
    }
}

private struct ResolvedPaths {
    let modelsDirectory: URL
    let ggmlModelURL: URL
    let coreMLZipURL: URL
    let coreMLDirectoryURL: URL
    let manifestURL: URL
}

private enum InstallValidationResult: Equatable {
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
