import Combine
import Foundation

enum PocketTTSInstallState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case installing(progress: Double)
    case ready
    case failed(String)

    var statusText: String {
        switch self {
        case .notInstalled:
            return "Not installed"
        case .downloading:
            return "Downloading playback model"
        case .installing:
            return "Installing playback model"
        case .ready:
            return "Installed"
        case .failed:
            return "Install failed"
        }
    }
}

private enum PocketTTSInstallTarget: Equatable {
    case sharedModel
    case voice(AppSettingsStore.TTSVoice)
}

@MainActor
final class PocketTTSModelManager: ObservableObject {
    @Published private(set) var sharedModelInstallState: PocketTTSInstallState = .notInstalled
    @Published private(set) var voiceInstallStates: [AppSettingsStore.TTSVoice: PocketTTSInstallState]
    @Published private var activeInstallTarget: PocketTTSInstallTarget?

    private let fileManager: FileManager
    private let session: URLSession
    private let assetLocator: PocketTTSAssetLocator
    private var installTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        assetLocator: PocketTTSAssetLocator? = nil
    ) {
        self.fileManager = fileManager
        self.session = session
        self.assetLocator = assetLocator ?? PocketTTSAssetLocator(fileManager: fileManager)
        self.voiceInstallStates = Dictionary(
            uniqueKeysWithValues: AppSettingsStore.TTSVoice.allCases.map { ($0, .notInstalled) }
        )
        refreshStatus()
    }

    var installState: PocketTTSInstallState {
        sharedModelInstallState
    }

    func installState(for voice: AppSettingsStore.TTSVoice) -> PocketTTSInstallState {
        voiceInstallStates[voice] ?? .notInstalled
    }

    func refreshStatus() {
        guard installTask == nil else { return }
        sharedModelInstallState = assetLocator.isSharedModelInstalled() ? .ready : .notInstalled
        for voice in AppSettingsStore.TTSVoice.allCases {
            voiceInstallStates[voice] = assetLocator.isVoiceInstalled(voice) ? .ready : .notInstalled
        }
    }

    func handleAppDidBecomeActive() {
        refreshStatus()
    }

    func handleAppDidEnterBackground() {}

    func isSharedModelReady() -> Bool {
        assetLocator.isSharedModelInstalled()
    }

    func isVoiceReady(_ voice: AppSettingsStore.TTSVoice) -> Bool {
        assetLocator.isVoiceInstalled(voice)
    }

    func isReady(for voice: AppSettingsStore.TTSVoice) -> Bool {
        assetLocator.isReady(for: voice)
    }

    func installedVoices() -> [AppSettingsStore.TTSVoice] {
        AppSettingsStore.TTSVoice.allCases.filter { isVoiceReady($0) }
    }

    func isBusyInstallingAnotherTarget(sharedModel: Bool = false, voice: AppSettingsStore.TTSVoice? = nil) -> Bool {
        guard let activeInstallTarget else { return false }
        if sharedModel {
            return activeInstallTarget != .sharedModel
        }
        if let voice {
            return activeInstallTarget != .voice(voice)
        }
        return true
    }

    func downloadModel() {
        downloadSharedModel()
    }

    func downloadSharedModel() {
        guard installTask == nil else { return }
        activeInstallTarget = .sharedModel

        installTask = Task { [fileManager, session] in
            do {
                Self.log("Shared model install requested.")
                await MainActor.run {
                    self.sharedModelInstallState = .downloading(progress: 0)
                }

                let descriptor = try await PocketTTSModelCatalog.fetchSharedModelDescriptor(session: session)
                try await self.install(
                    descriptor: descriptor,
                    target: .sharedModel,
                    stagingRootURL: try Self.makeStagingRootURL(fileManager: fileManager, target: .sharedModel),
                    finalRootURL: try Self.finalSharedModelRootURL(fileManager: fileManager),
                    progress: { progress in
                        self.sharedModelInstallState = .downloading(progress: progress)
                    },
                    installing: {
                        self.sharedModelInstallState = .installing(progress: 0.95)
                    }
                )

                let manifest = PocketTTSInstallManifest(
                    sourceRepository: PocketTTSModelCatalog.repositoryID,
                    artifactSizesByRelativePath: Dictionary(
                        uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedByteCount) }
                    )
                )
                try Self.writeManifest(
                    manifest,
                    to: try Self.finalSharedManifestRootURL(fileManager: fileManager)
                )

                guard self.assetLocator.isSharedModelInstalled() else {
                    throw NSError(
                        domain: "PocketTTSModelManager",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "PocketTTS install validation failed."]
                    )
                }

                await MainActor.run {
                    self.sharedModelInstallState = .ready
                }
                Self.log("Shared model install completed successfully.")
            } catch {
                Self.log("Shared model install failed with error: \(error.localizedDescription)")
                await MainActor.run {
                    self.sharedModelInstallState = .failed(error.localizedDescription)
                }
            }

            await MainActor.run {
                self.installTask = nil
                self.activeInstallTarget = nil
            }
        }
    }

    func deleteModel() {
        deleteSharedModel()
    }

    func deleteSharedModel() {
        Self.log("Deleting installed PocketTTS shared model assets.")
        installTask?.cancel()
        installTask = nil
        activeInstallTarget = nil

        if let rootURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) {
            try? fileManager.removeItem(at: rootURL)
        }
        refreshStatus()
    }

    func repairModelIfNeeded() {
        repairSharedModelIfNeeded()
    }

    func repairSharedModelIfNeeded() {
        deleteSharedModel()
        downloadSharedModel()
    }

    func downloadVoice(_ voice: AppSettingsStore.TTSVoice) {
        guard installTask == nil else { return }
        activeInstallTarget = .voice(voice)

        installTask = Task { [fileManager, session] in
            do {
                Self.log("Voice install requested for \(voice.rawValue).")
                await MainActor.run {
                    self.voiceInstallStates[voice] = .downloading(progress: 0)
                }

                let descriptor = try await PocketTTSModelCatalog.fetchVoiceDescriptor(for: voice, session: session)
                try await self.install(
                    descriptor: descriptor,
                    target: .voice(voice),
                    stagingRootURL: try Self.makeStagingRootURL(fileManager: fileManager, target: .voice(voice)),
                    finalRootURL: try Self.finalVoiceRootURL(voice, fileManager: fileManager),
                    progress: { progress in
                        self.voiceInstallStates[voice] = .downloading(progress: progress)
                    },
                    installing: {
                        self.voiceInstallStates[voice] = .installing(progress: 0.95)
                    }
                )

                let manifest = PocketTTSInstallManifest(
                    sourceRepository: PocketTTSModelCatalog.repositoryID,
                    artifactSizesByRelativePath: Dictionary(
                        uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedByteCount) }
                    )
                )
                try Self.writeManifest(
                    manifest,
                    to: try Self.finalVoiceRootURL(voice, fileManager: fileManager)
                )

                guard self.assetLocator.isVoiceInstalled(voice) else {
                    throw NSError(
                        domain: "PocketTTSModelManager",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: "\(voice.displayName) voice install validation failed."]
                    )
                }

                await MainActor.run {
                    self.voiceInstallStates[voice] = .ready
                }
                Self.log("Voice install completed successfully for \(voice.rawValue).")
            } catch {
                Self.log("Voice install failed for \(voice.rawValue) with error: \(error.localizedDescription)")
                await MainActor.run {
                    self.voiceInstallStates[voice] = .failed(error.localizedDescription)
                }
            }

            await MainActor.run {
                self.installTask = nil
                self.activeInstallTarget = nil
            }
        }
    }

    func deleteVoice(_ voice: AppSettingsStore.TTSVoice) {
        if let voiceRootURL = SharedPaths.pocketTTSVoiceDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(voice.rawValue, isDirectory: true) {
            try? fileManager.removeItem(at: voiceRootURL)
        }
        voiceInstallStates[voice] = .notInstalled
        refreshStatus()
    }

    func repairVoiceIfNeeded(_ voice: AppSettingsStore.TTSVoice) {
        deleteVoice(voice)
        downloadVoice(voice)
    }

    private func install(
        descriptor: PocketTTSDescriptor,
        target: PocketTTSInstallTarget,
        stagingRootURL: URL,
        finalRootURL: URL,
        progress: @escaping @MainActor (Double) -> Void,
        installing: @escaping @MainActor () -> Void
    ) async throws {
        Self.log("Fetched descriptor with \(descriptor.artifacts.count) artifacts (\(descriptor.requiredDownloadBytes) bytes).")
        try Self.prepareDirectory(stagingRootURL, fileManager: fileManager)
        Self.log("Prepared staging directory at \(stagingRootURL.path).")

        var completedBytes: Int64 = 0
        let totalBytes = max(descriptor.requiredDownloadBytes, 1)

        for artifact in descriptor.artifacts {
            let destinationURL = stagingRootURL.appendingPathComponent(artifact.relativePath, isDirectory: false)
            try Self.prepareParentDirectory(for: destinationURL, fileManager: fileManager)

            if artifact.expectedByteCount == 0 {
                try Data().write(to: destinationURL, options: [.atomic])
            } else {
                Self.log("Downloading artifact \(artifact.relativePath) from \(artifact.remoteURL.absoluteString).")
                let temporaryURL = try await Self.download(artifact.remoteURL, using: session)
                try Self.replaceItem(at: destinationURL, with: temporaryURL, fileManager: fileManager)
            }

            completedBytes += artifact.expectedByteCount
            let currentProgress = min(max(Double(completedBytes) / Double(totalBytes), 0), 0.92)
            await MainActor.run {
                progress(currentProgress)
            }
        }

        await MainActor.run {
            installing()
        }

        switch target {
        case .sharedModel:
            try Self.replaceDirectory(at: finalRootURL, with: stagingRootURL.appendingPathComponent("Model", isDirectory: true), fileManager: fileManager)
        case .voice(let voice):
            let stagedVoiceDirectoryURL = stagingRootURL
                .appendingPathComponent("Voices", isDirectory: true)
                .appendingPathComponent(voice.rawValue, isDirectory: true)
            try Self.replaceDirectory(at: finalRootURL, with: stagedVoiceDirectoryURL, fileManager: fileManager)
        }
    }

    private static func finalSharedModelRootURL(fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSModelDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the PocketTTS model install directory."]
            )
        }
        return rootURL
    }

    private static func finalSharedManifestRootURL(fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the PocketTTS root directory."]
            )
        }
        return rootURL
    }

    private static func finalVoiceRootURL(_ voice: AppSettingsStore.TTSVoice, fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSVoiceDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(voice.rawValue, isDirectory: true) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the \(voice.displayName) voice install directory."]
            )
        }
        return rootURL
    }

    private static func makeStagingRootURL(
        fileManager: FileManager,
        target: PocketTTSInstallTarget
    ) throws -> URL {
        guard let ttsDirectoryURL = SharedPaths.ttsDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create the PocketTTS staging directory."]
            )
        }

        let stagingComponent: String
        switch target {
        case .sharedModel:
            stagingComponent = "pockettts-model"
        case .voice(let voice):
            stagingComponent = "pockettts-voice-\(voice.rawValue)"
        }

        return ttsDirectoryURL
            .appendingPathComponent("staging", isDirectory: true)
            .appendingPathComponent(stagingComponent, isDirectory: true)
    }

    private static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: url.path) {
            log("Removing stale staging directory at \(url.path).")
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func prepareParentDirectory(for url: URL, fileManager: FileManager) throws {
        let parentURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
    }

    private static func download(_ url: URL, using session: URLSession) async throws -> URL {
        let (temporaryURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            log("Download request failed for \(url.absoluteString).")
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "PocketTTS download failed."]
            )
        }
        log("Download request succeeded for \(url.absoluteString) with status \(httpResponse.statusCode).")
        return temporaryURL
    }

    private static func replaceItem(at destinationURL: URL, with temporaryURL: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    private static func writeManifest(_ manifest: PocketTTSInstallManifest, to rootURL: URL) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        let manifestURL = rootURL.appendingPathComponent(PocketTTSInstallManifest.filename, isDirectory: false)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private static func replaceDirectory(at destinationURL: URL, with stagingURL: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            log("Removing previous install at \(destinationURL.path).")
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
    }

    private static func log(_ message: String) {
        NSLog("[PocketTTSModelManager] %@", message)
    }
}
