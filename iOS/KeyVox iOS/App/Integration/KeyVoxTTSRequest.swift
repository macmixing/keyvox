import Foundation

enum KeyVoxTTSRequestSourceSurface: String, Codable, Equatable {
    case keyboard
    case app
    case shareExtension = "share_extension"
}

enum KeyVoxTTSRequestKind: String, Codable, Equatable {
    case speakClipboardText
}

struct KeyVoxTTSRequest: Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: TimeInterval
    let sourceSurface: KeyVoxTTSRequestSourceSurface
    let voiceID: String
    let kind: KeyVoxTTSRequestKind

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
