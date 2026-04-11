import Foundation

enum KeyVoxPlaybackVoice: String, CaseIterable, Identifiable, Codable {
    case alba
    case azelma
    case cosette
    case eponine
    case fantine
    case javert
    case jean
    case marius

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alba:
            return "Alba"
        case .azelma:
            return "Azelma"
        case .cosette:
            return "Cosette"
        case .eponine:
            return "Eponine"
        case .fantine:
            return "Fantine"
        case .javert:
            return "Javert"
        case .jean:
            return "Jean"
        case .marius:
            return "Marius"
        }
    }
}
