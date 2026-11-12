import Foundation

enum DictionarySortMode: String, CaseIterable, Identifiable {
    case alphabetical = "A-Z"
    case recentlyAdded = "Recently Added"

    var id: Self { self }

    var title: String {
        switch self {
        case .alphabetical:
            return String(localized: "A-Z", comment: "Dictionary sort option that orders entries alphabetically.")
        case .recentlyAdded:
            return String(localized: "Recently Added", comment: "Dictionary sort option that shows the newest entries first.")
        }
    }
}
