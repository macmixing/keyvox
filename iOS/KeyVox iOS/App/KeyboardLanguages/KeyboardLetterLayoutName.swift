import Foundation

/// The name a letter layout is shown by: the name the system's own Keyboard settings show for it
/// (the system Settings app's `KeyboardLayouts` strings in iOS 27.2), in the language the app is
/// shown in. Layouts are told apart by these names alone; no two of them share one.
nonisolated enum KeyboardLetterLayoutName {
    /// The name shown for the layout `identifier` names, or the identifier itself for a layout no
    /// name is written for.
    static func displayName(for identifier: String) -> String {
        systemName(for: identifier) ?? identifier
    }

    /// The system's name for the layout `identifier` names, or nil when none is written for it.
    static func systemName(for identifier: String) -> String? {
        switch identifier {
        case "QWERTY":
            String(localized: "QWERTY", comment: "Name of a keyboard letter layout, as the system's Keyboard settings show it.")
        case "AZERTY":
            String(localized: "AZERTY", comment: "Name of a keyboard letter layout, as the system's Keyboard settings show it.")
        case "QWERTZ":
            String(localized: "QWERTZ", comment: "Name of a keyboard letter layout, as the system's Keyboard settings show it.")
        case "Dvorak":
            String(localized: "Dvorak", comment: "Name of a keyboard letter layout, as the system's Keyboard settings show it.")
        case "AZERTY-French":
            String(localized: "AZERTY – French", comment: "Name of the French AZERTY keyboard letter layout, as the system's Keyboard settings show it.")
        case "QWERTY-Accents":
            String(localized: "QWERTY – French", comment: "Name of the French QWERTY keyboard letter layout, as the system's Keyboard settings show it.")
        case "QWERTZ-Accents":
            String(localized: "QWERTZ – French", comment: "Name of the French QWERTZ keyboard letter layout, as the system's Keyboard settings show it.")
        case "QWERTY-Spanish":
            String(localized: "QWERTY – Spanish", comment: "Name of the Spanish QWERTY keyboard letter layout, as the system's Keyboard settings show it.")
        case "QWERTZ-German":
            String(localized: "QWERTZ – German", comment: "Name of the German QWERTZ keyboard letter layout, as the system's Keyboard settings show it.")
        default:
            nil
        }
    }
}
