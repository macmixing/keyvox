import Foundation
import KeyVoxTTS

protocol PocketTTSEngineRuntime: AnyObject {
    func prepareIfNeeded() async throws
    func prepareVoiceIfNeeded(_ voice: KeyVoxTTSVoice) async throws
    func setPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) async
    func requestPreferredComputeMode(_ mode: KeyVoxTTSComputeMode)
    func synthesizeStreaming(
        text: String,
        voice: KeyVoxTTSVoice,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>
}

private final class LivePocketTTSEngineRuntime: PocketTTSEngineRuntime {
    private let runtime: KeyVoxPocketTTSRuntime

    init(assetLayout: KeyVoxTTSAssetLayout) {
        self.runtime = KeyVoxPocketTTSRuntime(assetLayout: assetLayout)
    }

    func prepareIfNeeded() async throws {
        try await runtime.prepareIfNeeded()
    }

    func prepareVoiceIfNeeded(_ voice: KeyVoxTTSVoice) async throws {
        try await runtime.prepareVoiceIfNeeded(voice)
    }

    func setPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) async {
        await runtime.setPreferredComputeMode(mode)
    }

    func requestPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) {
        runtime.requestPreferredComputeMode(mode)
    }

    func synthesizeStreaming(
        text: String,
        voice: KeyVoxTTSVoice,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error> {
        try await runtime.synthesizeStreaming(
            text: text,
            voice: voice,
            fastModeEnabled: fastModeEnabled
        )
    }
}

final class PocketTTSEngine: TTSEngine {
    private let assetLayoutProvider: () -> KeyVoxTTSAssetLayout?
    private let sharedModelInstalledProvider: () -> Bool
    private let runtimeFactory: (KeyVoxTTSAssetLayout) -> any PocketTTSEngineRuntime
    private var runtime: (any PocketTTSEngineRuntime)?
    private var isRuntimePrepared = false
    private var loadedRootDirectoryURL: URL?
    private var loadedAssetFingerprint: String?

    private let fileManager: FileManager
    
    init(
        fileManager: FileManager = .default,
        assetLayoutProvider: (() -> KeyVoxTTSAssetLayout?)? = nil,
        sharedModelInstalledProvider: (() -> Bool)? = nil,
        runtimeFactory: ((KeyVoxTTSAssetLayout) -> any PocketTTSEngineRuntime)? = nil
    ) {
        self.fileManager = fileManager
        let assetLocator = PocketTTSAssetLocator(fileManager: fileManager)
        self.assetLayoutProvider = assetLayoutProvider ?? { assetLocator.assetLayout() }
        self.sharedModelInstalledProvider = sharedModelInstalledProvider ?? { assetLocator.isSharedModelInstalled() }
        self.runtimeFactory = runtimeFactory ?? { assetLayout in
            LivePocketTTSEngineRuntime(assetLayout: assetLayout)
        }
    }

    func prepareIfNeeded() async throws {
        Self.log("PocketTTS model load begin.")
        let runtime = try runtimeForInstalledAssets()
        try await runtime.prepareIfNeeded()
        isRuntimePrepared = true
        Self.log("PocketTTS model load end.")
    }

    func prewarmVoiceIfNeeded(voiceID: String) async throws {
        let runtime = try runtimeForInstalledAssets()
        guard let voice = KeyVoxTTSVoice(rawValue: voiceID) else {
            throw KeyVoxTTSError.invalidVoice("PocketTTS voice \(voiceID) is not supported.")
        }

        Self.log("Prewarming PocketTTS voice \(voiceID).")
        try await runtime.prepareVoiceIfNeeded(voice)
        isRuntimePrepared = true
        Self.log("Prewarmed PocketTTS voice \(voiceID).")
    }

    func unloadIfNeeded() {
        guard runtime != nil else { return }
        Self.log("PocketTTS model unload begin.")
        runtime = nil
        isRuntimePrepared = false
        loadedRootDirectoryURL = nil
        loadedAssetFingerprint = nil
        Self.log("PocketTTS model unload end.")
    }

    func prepareForForegroundSynthesis() async {
        guard let runtime, isRuntimePrepared else { return }
        await runtime.setPreferredComputeMode(.foreground)
        Self.log("Set PocketTTS to foreground synthesis mode.")
    }

    func prepareForBackgroundContinuation() async {
        guard let runtime, isRuntimePrepared else { return }
        await runtime.setPreferredComputeMode(.backgroundSafe)
        Self.log("Set PocketTTS to background-safe synthesis mode.")
    }

    func requestForegroundSynthesisImmediately() {
        guard let runtime, isRuntimePrepared else { return }
        runtime.requestPreferredComputeMode(.foreground)
        Self.log("Requested immediate foreground synthesis mode.")
    }

    func requestBackgroundContinuationImmediately() {
        guard let runtime, isRuntimePrepared else { return }
        runtime.requestPreferredComputeMode(.backgroundSafe)
        Self.log("Requested immediate background-safe synthesis mode.")
    }

    func makeAudioStream(
        for text: String,
        voiceID: String,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error> {
        Self.log("Creating audio stream for voice \(voiceID).")
        let runtime = try runtimeForInstalledAssets()
        guard let voice = KeyVoxTTSVoice(rawValue: voiceID) else {
            throw KeyVoxTTSError.invalidVoice("PocketTTS voice \(voiceID) is not supported.")
        }

        return try await runtime.synthesizeStreaming(
            text: text,
            voice: voice,
            fastModeEnabled: fastModeEnabled
        )
    }

    private func runtimeForInstalledAssets() throws -> any PocketTTSEngineRuntime {
        guard sharedModelInstalledProvider(),
              let assetLayout = assetLayoutProvider() else {
            Self.log("Runtime request failed because assets are not installed.")
            throw KeyVoxTTSError.missingAsset("PocketTTS assets are not installed.")
        }

        let currentFingerprint = computeAssetFingerprint(for: assetLayout)
        let needsRecreate = runtime == nil || 
                           loadedRootDirectoryURL != assetLayout.rootDirectoryURL ||
                           loadedAssetFingerprint != currentFingerprint
        
        if needsRecreate {
            Self.log("Creating runtime for installed assets at \(assetLayout.rootDirectoryURL.path).")
            runtime = runtimeFactory(assetLayout)
            isRuntimePrepared = false
            loadedRootDirectoryURL = assetLayout.rootDirectoryURL
            loadedAssetFingerprint = currentFingerprint
        }
        return runtime!
    }
    
    private func computeAssetFingerprint(for assetLayout: KeyVoxTTSAssetLayout) -> String {
        var components: [String] = []
        
        components.append(assetLayout.rootDirectoryURL.path)
        
        if let attrs = try? fileManager.attributesOfItem(atPath: assetLayout.modelDirectoryURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            components.append(String(modDate.timeIntervalSince1970))
        }
        
        if let attrs = try? fileManager.attributesOfItem(atPath: assetLayout.constantsDirectoryURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            components.append(String(modDate.timeIntervalSince1970))
        }
        
        if let attrs = try? fileManager.attributesOfItem(atPath: assetLayout.voiceDirectoryURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            components.append(String(modDate.timeIntervalSince1970))
        }
        
        return components.joined(separator: "|")
    }

    private static func log(_ message: String) {
        #if DEBUG
        NSLog("[PocketTTSEngine] %@", message)
        #endif
    }
}
