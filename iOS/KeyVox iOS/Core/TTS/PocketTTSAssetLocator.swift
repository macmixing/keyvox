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

    func manifestURL() -> URL? {
        SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(PocketTTSInstallManifest.filename, isDirectory: false)
    }

    func isInstalled() -> Bool {
        guard let layout = assetLayout(),
              let manifestURL = manifestURL(),
              fileManager.fileExists(atPath: manifestURL.path),
              let manifest = readManifest(from: manifestURL),
              manifest.version == PocketTTSInstallManifest.currentVersion else {
            log("Install validation failed before file checks.")
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

        guard AppSettingsStore.TTSVoice.allCases.allSatisfy({
            let nestedPath = layout.voiceDirectoryURL
                .appendingPathComponent($0.rawValue, isDirectory: true)
                .appendingPathComponent("audio_prompt.bin", isDirectory: false)
            let flatPath = layout.voiceDirectoryURL
                .appendingPathComponent("\($0.rawValue)_audio_prompt.bin", isDirectory: false)
            let fallbackPath = layout.constantsDirectoryURL
                .appendingPathComponent("\($0.rawValue)_audio_prompt.bin", isDirectory: false)
            return fileManager.fileExists(atPath: nestedPath.path)
                || fileManager.fileExists(atPath: flatPath.path)
                || fileManager.fileExists(atPath: fallbackPath.path)
        }) else {
            log("One or more voice prompts are missing.")
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

    private func readManifest(from url: URL) -> PocketTTSInstallManifest? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(PocketTTSInstallManifest.self, from: data)
    }

    private func log(_ message: String) {
        NSLog("[PocketTTSAssetLocator] %@", message)
    }
}
