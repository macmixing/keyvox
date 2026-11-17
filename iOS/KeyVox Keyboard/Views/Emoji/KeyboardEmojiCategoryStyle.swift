import Foundation
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
        String(localized: "\(name) category", comment: "VoiceOver label for an emoji category button in the emoji keyboard. %@ is the category name.")
    }

    private var name: String {
        switch self {
        case .frequentlyUsed: String(localized: "Frequently Used", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .smileysPeople: String(localized: "Smileys & People", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .animalsNature: String(localized: "Animals & Nature", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .foodDrink: String(localized: "Food & Drink", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .activity: String(localized: "Activity", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .travelPlaces: String(localized: "Travel & Places", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .objects: String(localized: "Objects", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .symbols: String(localized: "Symbols", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        case .flags: String(localized: "Flags", comment: "Emoji category name read by VoiceOver in the emoji keyboard. Use the name the system emoji keyboard uses in this language.")
        }
    }
}
