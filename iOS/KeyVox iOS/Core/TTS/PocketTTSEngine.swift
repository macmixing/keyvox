import Foundation
import KeyVoxTTS

final class PocketTTSEngine: TTSEngine {
    private let assetLocator: PocketTTSAssetLocator
    private var runtime: KeyVoxPocketTTSRuntime?
    private var loadedRootDirectoryURL: URL?
    private var loadedAssetFingerprint: String?

    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.assetLocator = PocketTTSAssetLocator(fileManager: fileManager)
    }

    func prepareIfNeeded() async throws {
        Self.log("Preparing PocketTTS runtime.")
        let runtime = try runtimeForInstalledAssets()
        try await runtime.prepareIfNeeded()
        Self.log("PocketTTS runtime prepared.")
    }

    func prewarmVoiceIfNeeded(voiceID: String) async throws {
        let runtime = try runtimeForInstalledAssets()
        guard let voice = KeyVoxTTSVoice(rawValue: voiceID) else {
            throw KeyVoxTTSError.invalidVoice("PocketTTS voice \(voiceID) is not supported.")
        }

        Self.log("Prewarming PocketTTS voice \(voiceID).")
        try await runtime.prepareVoiceIfNeeded(voice)
        Self.log("Prewarmed PocketTTS voice \(voiceID).")
    }

    func prepareForForegroundSynthesis() async {
        do {
            let runtime = try runtimeForInstalledAssets()
            await runtime.setPreferredComputeMode(.foreground)
            Self.log("Set PocketTTS to foreground synthesis mode.")
        } catch {
            Self.log("Failed to set foreground synthesis mode: \(error.localizedDescription)")
        }
    }

    func prepareForBackgroundContinuation() async {
        do {
            let runtime = try runtimeForInstalledAssets()
            await runtime.setPreferredComputeMode(.backgroundSafe)
            Self.log("Set PocketTTS to background-safe synthesis mode.")
        } catch {
            Self.log("Failed to set background-safe synthesis mode: \(error.localizedDescription)")
        }
    }

    func requestForegroundSynthesisImmediately() {
        guard let runtime else { return }
        runtime.requestPreferredComputeMode(.foreground)
        Self.log("Requested immediate foreground synthesis mode.")
    }

    func requestBackgroundContinuationImmediately() {
        guard let runtime else { return }
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

    private func runtimeForInstalledAssets() throws -> KeyVoxPocketTTSRuntime {
        guard assetLocator.isSharedModelInstalled(),
              let assetLayout = assetLocator.assetLayout() else {
            Self.log("Runtime request failed because assets are not installed.")
            throw KeyVoxTTSError.missingAsset("PocketTTS assets are not installed.")
        }

        let currentFingerprint = computeAssetFingerprint(for: assetLayout)
        let needsRecreate = runtime == nil || 
                           loadedRootDirectoryURL != assetLayout.rootDirectoryURL ||
                           loadedAssetFingerprint != currentFingerprint
        
        if needsRecreate {
            Self.log("Creating runtime for installed assets at \(assetLayout.rootDirectoryURL.path).")
            runtime = KeyVoxPocketTTSRuntime(assetLayout: assetLayout)
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
