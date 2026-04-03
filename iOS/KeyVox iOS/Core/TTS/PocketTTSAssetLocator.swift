import Foundation
import KeyVoxTTS

struct PocketTTSAssetLocator {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func assetLayout() -> KeyVoxTTSAssetLayout? {
        guard let rootDirectoryURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            return nil
        }
        return KeyVoxTTSAssetLayout(rootDirectoryURL: rootDirectoryURL)
    }

    func sharedModelManifestURL() -> URL? {
        SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(PocketTTSInstallManifest.filename, isDirectory: false)
    }

    func voiceManifestURL(for voice: AppSettingsStore.TTSVoice) -> URL? {
        SharedPaths.pocketTTSVoiceDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(voice.rawValue, isDirectory: true)
            .appendingPathComponent(PocketTTSInstallManifest.filename, isDirectory: false)
    }

    func isInstalled() -> Bool {
        isSharedModelInstalled()
    }

    func isSharedModelInstalled() -> Bool {
        guard let layout = assetLayout(),
              let manifestURL = sharedModelManifestURL(),
              fileManager.fileExists(atPath: manifestURL.path),
              let manifest = readManifest(from: manifestURL),
              manifest.version == PocketTTSInstallManifest.currentVersion else {
            log("Shared install validation failed before file checks.")
            return false
        }

        let requiredModelURLs = [
            layout.modelDirectoryURL.appendingPathComponent("cond_step.mlmodelc", isDirectory: true),
            layout.modelDirectoryURL.appendingPathComponent("flowlm_step.mlmodelc", isDirectory: true),
            layout.modelDirectoryURL.appendingPathComponent("flow_decoder.mlmodelc", isDirectory: true),
            layout.modelDirectoryURL.appendingPathComponent("mimi_decoder_v2.mlmodelc", isDirectory: true),
        ]

        for modelURL in requiredModelURLs where fileManager.fileExists(atPath: modelURL.path) == false {
            log("Missing model directory \(modelURL.lastPathComponent).")
            return false
        }

        let requiredConstantURLs = [
            layout.constantsDirectoryURL.appendingPathComponent("bos_emb.bin", isDirectory: false),
            layout.constantsDirectoryURL.appendingPathComponent("text_embed_table.bin", isDirectory: false),
            layout.constantsDirectoryURL.appendingPathComponent("tokenizer.model", isDirectory: false),
            layout.constantsDirectoryURL.appendingPathComponent("manifest.json", isDirectory: false),
            layout.constantsDirectoryURL.appendingPathComponent("mimi_init_state", isDirectory: true),
        ]

        for assetURL in requiredConstantURLs where fileManager.fileExists(atPath: assetURL.path) == false {
            log("Missing constant asset at \(assetURL.path).")
            return false
        }

        return manifest.artifactSizesByRelativePath.allSatisfy { relativePath, expectedSize in
            guard let rootDirectoryURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
                log("Install validation could not resolve the root directory.")
                return false
            }

            let fileURL = rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let actualSize = attributes[.size] as? NSNumber else {
                log("Missing or unreadable artifact at \(fileURL.path).")
                return false
            }

            if actualSize.int64Value != expectedSize {
                log("Artifact size mismatch for \(relativePath): expected \(expectedSize), got \(actualSize.int64Value).")
            }
            return actualSize.int64Value == expectedSize
        }
    }

    func isVoiceInstalled(_ voice: AppSettingsStore.TTSVoice) -> Bool {
        guard let layout = assetLayout(),
              let manifestURL = voiceManifestURL(for: voice),
              fileManager.fileExists(atPath: manifestURL.path),
              let manifest = readManifest(from: manifestURL),
              manifest.version == PocketTTSInstallManifest.currentVersion else {
            log("Voice install validation failed before file checks for \(voice.rawValue).")
            return false
        }

        guard let runtimeVoice = KeyVoxTTSVoice(rawValue: voice.rawValue) else {
            log("Voice \(voice.rawValue) is not supported by the TTS runtime.")
            return false
        }

        let promptURL = voicePromptURL(for: runtimeVoice, layout: layout)
        guard fileManager.fileExists(atPath: promptURL.path) else {
            log("Missing voice prompt for \(voice.rawValue) at \(promptURL.path).")
            return false
        }

        return manifest.artifactSizesByRelativePath.allSatisfy { relativePath, expectedSize in
            guard let rootDirectoryURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
                log("Voice validation could not resolve the root directory.")
                return false
            }

            let fileURL = rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let actualSize = attributes[.size] as? NSNumber else {
                log("Missing or unreadable voice artifact at \(fileURL.path).")
                return false
            }

            if actualSize.int64Value != expectedSize {
                log("Voice artifact size mismatch for \(relativePath): expected \(expectedSize), got \(actualSize.int64Value).")
            }
            return actualSize.int64Value == expectedSize
        }
    }

    func isReady(for voice: AppSettingsStore.TTSVoice) -> Bool {
        isSharedModelInstalled() && isVoiceInstalled(voice)
    }

    private func readManifest(from url: URL) -> PocketTTSInstallManifest? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(PocketTTSInstallManifest.self, from: data)
    }

    private func voicePromptURL(for voice: KeyVoxTTSVoice, layout: KeyVoxTTSAssetLayout) -> URL {
        let nestedURL = layout.voiceDirectoryURL
            .appendingPathComponent(voice.rawValue, isDirectory: true)
            .appendingPathComponent("audio_prompt.bin", isDirectory: false)
        if fileManager.fileExists(atPath: nestedURL.path) {
            return nestedURL
        }

        let flatURL = layout.voiceDirectoryURL
            .appendingPathComponent("\(voice.rawValue)_audio_prompt.bin", isDirectory: false)
        if fileManager.fileExists(atPath: flatURL.path) {
            return flatURL
        }

        return layout.constantsDirectoryURL
            .appendingPathComponent("\(voice.rawValue)_audio_prompt.bin", isDirectory: false)
    }

    private func log(_ message: String) {
        NSLog("[PocketTTSAssetLocator] %@", message)
    }
}
