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
            return String(localized: "Home", comment: "Name of the app's Home tab, used as its screen title.")
        case .dictionary:
            return String(localized: "Dictionary", comment: "Name of the app's Dictionary tab, where the user manages custom words. Used as its screen title.")
        case .style:
            return String(localized: "Style", comment: "Name of the app's Style tab, where the user picks formatting and Vibes options. Used as its screen title.")
        case .settings:
            return String(localized: "Settings", comment: "Name of the app's Settings tab, used as its screen title.")
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
    @Published private(set) var settingsModelSectionExpansionRequestID: UUID?

    private var shouldSuppressNextSelectionHaptic = false

    func selectTab(_ tab: ContainingAppTab, suppressesHaptic: Bool = false) {
        shouldSuppressNextSelectionHaptic = suppressesHaptic && tab != selectedTab
        selectedTab = tab
    }

    func openSettingsModelSection() {
        selectTab(.settings, suppressesHaptic: true)
        DispatchQueue.main.async { [weak self] in
            self?.settingsModelSectionExpansionRequestID = UUID()
        }
    }

    func consumeShouldSuppressNextSelectionHaptic() -> Bool {
        defer { shouldSuppressNextSelectionHaptic = false }
        return shouldSuppressNextSelectionHaptic
    }
}
