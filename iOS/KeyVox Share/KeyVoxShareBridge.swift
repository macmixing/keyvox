import Foundation

struct KeyVoxShareTTSRequest: Codable {
    let id: UUID
    let text: String
    let createdAt: TimeInterval
    let sourceSurface: String
    let voiceID: String
    let kind: String
}

enum KeyVoxShareBridge {
    static let appGroupID = "group.com.cueit.keyvox"
    static let ttsVoiceDefaultsKey = "KeyVox.TTSVoice"
    static let startTTSURL = URL(string: "keyvoxios://tts/start")

    static func writeTTSRequest(_ text: String, fileManager: FileManager = .default) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false,
              let requestURL = ttsRequestURL(fileManager: fileManager) else {
            return
        }

        try? fileManager.createDirectory(
            at: requestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let request = KeyVoxShareTTSRequest(
            id: UUID(),
            text: trimmedText,
            createdAt: Date().timeIntervalSince1970,
            sourceSurface: "share_extension",
            voiceID: selectedVoiceID(),
            kind: "speakClipboardText"
        )

        guard let data = try? JSONEncoder().encode(request) else { return }
        try? data.write(to: requestURL, options: .atomic)
    }

    private static func selectedVoiceID() -> String {
        let defaults = UserDefaults(suiteName: appGroupID)
        return defaults?.string(forKey: ttsVoiceDefaultsKey) ?? "azelma"
    }

    private static func ttsRequestURL(fileManager: FileManager) -> URL? {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        return containerURL
            .appendingPathComponent("TTS", isDirectory: true)
            .appendingPathComponent("request.json", isDirectory: false)
    }
}
