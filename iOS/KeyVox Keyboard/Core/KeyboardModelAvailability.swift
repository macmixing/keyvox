import Foundation

enum KeyboardModelAvailability {
    private static let supportedTTSVoiceIDs = [
        "alba",
        "azelma",
        "cosette",
        "eponine",
        "fantine",
        "javert",
        "jean",
        "marius",
    ]

    private static func modelsDirectoryURL(fileManager: FileManager) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID)?
            .appendingPathComponent("Models", isDirectory: true)
    }

    private static func pocketTTSRootDirectoryURL(fileManager: FileManager) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("tts", isDirectory: true)
            .appendingPathComponent("pockettts", isDirectory: true)
    }

    private static func pocketTTSVoiceDirectoryURL(fileManager: FileManager) -> URL? {
        pocketTTSRootDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("Voices", isDirectory: true)
    }

    static func isInstalled(fileManager: FileManager = .default) -> Bool {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID
        ) else {
            return false
        }

        let modelsDirectory = containerURL.appendingPathComponent("Models", isDirectory: true)
        return whisperIsInstalled(in: modelsDirectory, fileManager: fileManager)
            || parakeetIsInstalled(in: modelsDirectory, fileManager: fileManager)
    }

    static func isTTSReady(
        preferredVoiceID: String?,
        fileManager: FileManager = .default
    ) -> Bool {
        guard isPocketTTSSharedModelInstalled(fileManager: fileManager),
              resolvedTTSVoiceID(preferredVoiceID: preferredVoiceID, fileManager: fileManager) != nil else {
            return false
        }

        return true
    }

    static func resolvedTTSVoiceID(
        preferredVoiceID: String?,
        fileManager: FileManager = .default
    ) -> String? {
        let installedVoiceIDs = installedTTSVoiceIDs(fileManager: fileManager)
        guard installedVoiceIDs.isEmpty == false else {
            return nil
        }

        if let preferredVoiceID,
           installedVoiceIDs.contains(preferredVoiceID) {
            return preferredVoiceID
        }

        for voiceID in supportedTTSVoiceIDs where installedVoiceIDs.contains(voiceID) {
            return voiceID
        }

        return installedVoiceIDs.sorted().first
    }

    private static func installedTTSVoiceIDs(fileManager: FileManager) -> Set<String> {
        guard let voicesDirectoryURL = pocketTTSVoiceDirectoryURL(fileManager: fileManager),
              let candidateURLs = try? fileManager.contentsOfDirectory(
                at: voicesDirectoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return Set(
            candidateURLs
                .filter { $0.hasDirectoryPath }
                .map { $0.lastPathComponent }
                .filter { isTTSVoiceInstalled($0, fileManager: fileManager) }
        )
    }

    private static func isPocketTTSSharedModelInstalled(fileManager: FileManager) -> Bool {
        guard let rootDirectoryURL = pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            return false
        }

        let requiredPaths = [
            "install-manifest.json",
            "Model/cond_step.mlmodelc",
            "Model/flowlm_step.mlmodelc",
            "Model/flow_decoder.mlmodelc",
            "Model/mimi_decoder_v2.mlmodelc",
            "Model/constants_bin/bos_emb.bin",
            "Model/constants_bin/text_embed_table.bin",
            "Model/constants_bin/tokenizer.model",
            "Model/constants_bin/manifest.json",
            "Model/constants_bin/mimi_init_state",
        ]

        return requiredPaths.allSatisfy { relativePath in
            fileManager.fileExists(atPath: rootDirectoryURL.appendingPathComponent(relativePath).path)
        }
    }

    private static func isTTSVoiceInstalled(_ voiceID: String, fileManager: FileManager) -> Bool {
        guard let rootDirectoryURL = pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            return false
        }

        let requiredPaths = [
            "Voices/\(voiceID)/install-manifest.json",
            "Voices/\(voiceID)/audio_prompt.bin",
        ]

        return requiredPaths.allSatisfy { relativePath in
            fileManager.fileExists(atPath: rootDirectoryURL.appendingPathComponent(relativePath).path)
        }
    }

    private static func whisperIsInstalled(in modelsDirectory: URL, fileManager: FileManager) -> Bool {
        let whisperRootURL = modelsDirectory.appendingPathComponent("whisper", isDirectory: true)
        let ggmlModelURL = whisperRootURL.appendingPathComponent("ggml-base.bin", isDirectory: false)
        let coreMLDirectoryURL = whisperRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
        let coreMLZipURL = whisperRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip", isDirectory: false)
        let manifestURL = whisperRootURL.appendingPathComponent("install-manifest.json", isDirectory: false)

        return fileManager.fileExists(atPath: ggmlModelURL.path)
            && fileManager.fileExists(atPath: coreMLDirectoryURL.path)
            && !fileManager.fileExists(atPath: coreMLZipURL.path)
            && fileManager.fileExists(atPath: manifestURL.path)
    }

    private static func parakeetIsInstalled(in modelsDirectory: URL, fileManager: FileManager) -> Bool {
        let parakeetRootURL = modelsDirectory.appendingPathComponent("parakeet", isDirectory: true)
        let manifestURL = parakeetRootURL.appendingPathComponent("install-manifest.json", isDirectory: false)
        let configURL = parakeetRootURL.appendingPathComponent("config.json", isDirectory: false)
        let vocabURL = parakeetRootURL.appendingPathComponent("parakeet_vocab.json", isDirectory: false)
        let jointModelURL = parakeetRootURL.appendingPathComponent("JointDecision.mlmodelc", isDirectory: true)

        return fileManager.fileExists(atPath: manifestURL.path)
            && fileManager.fileExists(atPath: configURL.path)
            && fileManager.fileExists(atPath: vocabURL.path)
            && fileManager.fileExists(atPath: jointModelURL.path)
    }
}
