import KeyVoxEmoji

/// How the emoji page shows each category: an SF Symbol in its bar, standing in for the system
/// keyboard's pictures, which are not SF Symbols; and the system keyboard's wording for what
/// VoiceOver reads.
extension EmojiKeyboardCategory {
    var symbolName: String {
        switch self {
        case .frequentlyUsed: "clock"
        case .smileysPeople: "face.smiling"
        case .animalsNature: "pawprint"
        case .foodDrink: "takeoutbag.and.cup.and.straw"
        case .activity: "soccerball"
        case .travelPlaces: "car"
        case .objects: "lightbulb"
        case .symbols: "heart"
        case .flags: "flag"
        }
    }

    var accessibilityLabel: String {
        "\(name) category"
    }

    private var name: String {
        switch self {
        case .frequentlyUsed: "Frequently Used"
        case .smileysPeople: "Smileys & People"
        case .animalsNature: "Animals & Nature"
        case .foodDrink: "Food & Drink"
        case .activity: "Activity"
        case .travelPlaces: "Travel & Places"
        case .objects: "Objects"
        case .symbols: "Symbols"
        case .flags: "Flags"
        }
    }
}
