import Combine
import Foundation

enum ContainingAppTab: Hashable {
    case home
    case dictionary
    case style
    case settings

    private static let orderedTabs: [ContainingAppTab] = [
        .home,
        .dictionary,
        .style,
        .settings,
    ]

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

    var previous: ContainingAppTab? {
        guard let index = Self.orderedTabs.firstIndex(of: self), index > 0 else {
            return nil
        }

        return Self.orderedTabs[index - 1]
    }

    var next: ContainingAppTab? {
        guard let index = Self.orderedTabs.firstIndex(of: self) else {
            return nil
        }

        let nextIndex = Self.orderedTabs.index(after: index)
        guard nextIndex < Self.orderedTabs.endIndex else {
            return nil
        }

        return Self.orderedTabs[nextIndex]
    }
}

@MainActor
final class AppTabRouter: ObservableObject {
    @Published var selectedTab: ContainingAppTab = .home
}
