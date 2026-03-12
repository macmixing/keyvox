import Foundation

enum ContainingAppTab: Hashable {
    case home
    case dictionary
    case style
    case settings

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .dictionary:
            return "Dictionary"
        case .style:
            return "Style"
        case .settings:
            return "Settings"
        }
    }
}
