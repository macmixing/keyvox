import Foundation

public struct KeyVoxTTSAssetLayout: Sendable {
    public let rootDirectoryURL: URL
    public let modelDirectoryURL: URL
    public let constantsDirectoryURL: URL
    public let voiceDirectoryURL: URL

    public init(
        rootDirectoryURL: URL,
        modelDirectoryURL: URL,
        constantsDirectoryURL: URL,
        voiceDirectoryURL: URL
    ) {
        self.rootDirectoryURL = rootDirectoryURL
        self.modelDirectoryURL = modelDirectoryURL
        self.constantsDirectoryURL = constantsDirectoryURL
        self.voiceDirectoryURL = voiceDirectoryURL
    }

    public init(rootDirectoryURL: URL) {
        let modelDirectoryURL = rootDirectoryURL.appendingPathComponent("Model", isDirectory: true)
        let constantsDirectoryURL = modelDirectoryURL.appendingPathComponent("constants_bin", isDirectory: true)
        let voiceDirectoryURL = rootDirectoryURL.appendingPathComponent("Voices", isDirectory: true)
        self.init(
            rootDirectoryURL: rootDirectoryURL,
            modelDirectoryURL: modelDirectoryURL,
            constantsDirectoryURL: constantsDirectoryURL,
            voiceDirectoryURL: voiceDirectoryURL
        )
    }

    func compiledModelURL(named name: String) -> URL {
        modelDirectoryURL.appendingPathComponent(name + ".mlmodelc", isDirectory: true)
    }

    func voicePromptURL(for voice: KeyVoxTTSVoice) -> URL {
        let nestedURL = voiceDirectoryURL
            .appendingPathComponent(voice.rawValue, isDirectory: true)
            .appendingPathComponent("audio_prompt.bin", isDirectory: false)
        if FileManager.default.fileExists(atPath: nestedURL.path) {
            return nestedURL
        }

        let flatURL = voiceDirectoryURL.appendingPathComponent("\(voice.rawValue)_audio_prompt.bin", isDirectory: false)
        if FileManager.default.fileExists(atPath: flatURL.path) {
            return flatURL
        }

        return constantsDirectoryURL.appendingPathComponent("\(voice.rawValue)_audio_prompt.bin", isDirectory: false)
    }
}
