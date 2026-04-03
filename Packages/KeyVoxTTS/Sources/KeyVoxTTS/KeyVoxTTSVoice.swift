import Foundation

public enum KeyVoxTTSVoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case azelma
    case javert

    public var id: String { rawValue }
}
