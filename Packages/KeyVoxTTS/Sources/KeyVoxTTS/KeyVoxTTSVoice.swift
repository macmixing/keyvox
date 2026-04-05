import Foundation

public enum KeyVoxTTSVoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case alba
    case azelma
    case cosette
    case eponine
    case fantine
    case javert
    case jean
    case marius

    public var id: String { rawValue }
}
