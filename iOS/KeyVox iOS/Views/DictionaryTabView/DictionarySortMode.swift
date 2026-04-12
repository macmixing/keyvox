import Foundation

enum DictionarySortMode: String, CaseIterable, Identifiable {
    case alphabetical = "A-Z"
    case recentlyAdded = "Recently Added"

    var id: Self { self }
}
