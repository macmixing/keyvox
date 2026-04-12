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

    static var userFacingCases: [Self] {
        allCases.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // Raw values stay as stable internal codenames while displayName carries the branded UI label.
    var displayName: String {
        switch self {
        case .alba:
            return "Theo"
        case .azelma:
            return "Anne"
        case .cosette:
            return "Jordan"
        case .eponine:
            return "Sharon"
        case .fantine:
            return "Victoria"
        case .javert:
            return "Dean"
        case .jean:
            return "Jon"
        case .marius:
            return "Parker"
        }
    }
}
