import Foundation

enum KeyboardDictationModelStatus {
    enum Availability {
        case ready
        case notInstalled
        case actionRequired(String)
    }

    private enum Provider: String {
        case whisper
        case parakeet

        var displayName: String {
            switch self {
            case .whisper:
                return "Whisper"
            case .parakeet:
                return "Parakeet"
            }
        }
    }

    static func availability(fileManager: FileManager = .default) -> Availability {
        guard let modelsDirectory = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID)?
            .appendingPathComponent("Models", isDirectory: true) else {
            return .notInstalled
        }

        let provider = activeProvider()
        let state = modelState(for: provider, in: modelsDirectory, fileManager: fileManager)

        switch state {
        case .ready:
            return .ready
        case .missing:
            return .notInstalled
        case .updateRequired:
            return .actionRequired("Open KeyVox Settings and update \(provider.displayName)")
        case .repairRequired:
            return .actionRequired("Open KeyVox Settings and repair \(provider.displayName)")
        }
    }

    private enum ModelState {
        case missing
        case ready
        case updateRequired
        case repairRequired
    }

    private static func activeProvider() -> Provider {
        let defaults = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)
        guard let rawValue = defaults?.string(forKey: UserDefaultsKeys.App.activeDictationProvider),
              let provider = Provider(rawValue: rawValue) else {
            return .whisper
        }

        return provider
    }

    private static func modelState(
        for provider: Provider,
        in modelsDirectory: URL,
        fileManager: FileManager
    ) -> ModelState {
        switch provider {
        case .whisper:
            return whisperState(in: modelsDirectory, fileManager: fileManager)
        case .parakeet:
            return parakeetState(in: modelsDirectory, fileManager: fileManager)
        }
    }

    private static func whisperState(in modelsDirectory: URL, fileManager: FileManager) -> ModelState {
        let rootURL = modelsDirectory.appendingPathComponent("whisper", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("ggml-base.bin", isDirectory: false)
        let encoderURL = rootURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
        let encoderZipURL = rootURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip", isDirectory: false)
        let manifestURL = rootURL.appendingPathComponent("install-manifest.json", isDirectory: false)

        let hasAnyArtifact = [
            rootURL,
            modelURL,
            encoderURL,
            encoderZipURL,
            manifestURL,
        ].contains { fileManager.fileExists(atPath: $0.path) }

        guard hasAnyArtifact else { return .missing }

        guard fileManager.fileExists(atPath: modelURL.path),
              fileManager.fileExists(atPath: encoderURL.path),
              fileManager.fileExists(atPath: manifestURL.path),
              fileManager.fileExists(atPath: encoderZipURL.path) == false else {
            return .repairRequired
        }

        return .ready
    }

    private static func parakeetState(in modelsDirectory: URL, fileManager: FileManager) -> ModelState {
        let rootURL = modelsDirectory.appendingPathComponent("parakeet", isDirectory: true)
        let manifestURL = rootURL.appendingPathComponent("install-manifest.json", isDirectory: false)
        let configURL = rootURL.appendingPathComponent("config.json", isDirectory: false)
        let vocabURL = rootURL.appendingPathComponent("parakeet_vocab.json", isDirectory: false)
        let legacyEncoderURL = rootURL.appendingPathComponent("Encoder.mlmodelc", isDirectory: true)
        let legacyJointURL = rootURL.appendingPathComponent("JointDecision.mlmodelc", isDirectory: true)
        let legacyJointV2URL = rootURL.appendingPathComponent("JointDecisionv2.mlmodelc", isDirectory: true)
        let currentEncoderURL = rootURL.appendingPathComponent("EncoderInt4.mlmodelc", isDirectory: true)
        let currentJointURL = rootURL.appendingPathComponent("JointDecisionv3.mlmodelc", isDirectory: true)

        let hasAnyArtifact = [
            rootURL,
            manifestURL,
            configURL,
            vocabURL,
            legacyEncoderURL,
            legacyJointURL,
            legacyJointV2URL,
            currentEncoderURL,
            currentJointURL,
        ].contains { fileManager.fileExists(atPath: $0.path) }

        guard hasAnyArtifact else { return .missing }

        let hasBaseArtifacts = fileManager.fileExists(atPath: manifestURL.path)
            && fileManager.fileExists(atPath: configURL.path)
            && fileManager.fileExists(atPath: vocabURL.path)
        let hasCurrentArtifacts = fileManager.fileExists(atPath: currentEncoderURL.path)
            && fileManager.fileExists(atPath: currentJointURL.path)
        let hasLegacyArtifacts = fileManager.fileExists(atPath: legacyEncoderURL.path)
            && (
                fileManager.fileExists(atPath: legacyJointURL.path)
                    || fileManager.fileExists(atPath: legacyJointV2URL.path)
            )

        guard hasBaseArtifacts else { return .repairRequired }

        if hasCurrentArtifacts { return .ready }

        if hasLegacyArtifacts {
#if os(iOS)
            return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? .updateRequired : .ready
#else
            return .ready
#endif
        }

        return .repairRequired
    }
}
