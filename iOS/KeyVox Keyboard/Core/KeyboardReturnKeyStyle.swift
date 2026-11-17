import UIKit

/// How the return key looks for the focused field's return key type, as the system keyboard draws
/// it on iOS 27: a plain return arrow by default, a plain chevron for moving on to the next field,
/// and a blue key with the action's symbol for the rest.
struct KeyboardReturnKeyStyle: Hashable {
    let returnKeyType: UIReturnKeyType

    static let standard = KeyboardReturnKeyStyle(returnKeyType: .default)

    /// The symbol in place of the return arrow, or nil for the plain return arrow.
    var systemImageName: String? {
        switch returnKeyType {
        case .next, .continue:
            return "chevron.right"
        case .go, .join, .route:
            return "arrow.right"
        case .search, .google, .yahoo:
            return "magnifyingglass"
        case .send:
            return "arrow.up"
        case .done:
            return "checkmark"
        case .emergencyCall:
            return "phone"
        case .default:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Whether the key is the blue action key; the plain return arrow and the next-field chevron
    /// look like the other special keys.
    var isAction: Bool {
        switch returnKeyType {
        case .default, .next, .continue:
            return false
        case .go, .google, .join, .route, .search, .send, .yahoo, .done, .emergencyCall:
            return true
        @unknown default:
            return false
        }
    }

    var accessibilityLabel: String {
        switch returnKeyType {
        case .go:
            return String(localized: "Go", comment: "VoiceOver label for the keyboard's return key when the text field uses the Go return key. Use the name the system keyboard uses in this language.")
        case .join:
            return String(localized: "Join", comment: "VoiceOver label for the keyboard's return key when the text field uses the Join return key, such as when joining a network. Use the name the system keyboard uses in this language.")
        case .route:
            return String(localized: "Route", comment: "VoiceOver label for the keyboard's return key when the text field uses the Route return key in maps and directions. Use the name the system keyboard uses in this language.")
        case .search, .google, .yahoo:
            return String(localized: "Search", comment: "VoiceOver label for the keyboard's return key when the text field uses the Search return key. Use the name the system keyboard uses in this language.")
        case .send:
            return String(localized: "Send", comment: "VoiceOver label for the keyboard's return key when the text field uses the Send return key. Use the name the system keyboard uses in this language.")
        case .done:
            return String(localized: "Done", comment: "VoiceOver label for the keyboard's return key when the text field uses the Done return key. Use the name the system keyboard uses in this language.")
        case .next:
            return String(localized: "Next", comment: "VoiceOver label for the keyboard's return key when the text field uses the Next return key, which moves to the next field. Use the name the system keyboard uses in this language.")
        case .continue:
            return String(localized: "Continue", comment: "VoiceOver label for the keyboard's return key when the text field uses the Continue return key. Use the name the system keyboard uses in this language.")
        case .emergencyCall:
            return String(localized: "Emergency Call", comment: "VoiceOver label for the keyboard's return key when the text field uses the Emergency Call return key. Use the name the system uses in this language.")
        case .default:
            return String(localized: "Return", comment: "VoiceOver label for the keyboard's return key. Use the name the system keyboard uses in this language.")
        @unknown default:
            return String(localized: "Return", comment: "VoiceOver label for the keyboard's return key. Use the name the system keyboard uses in this language.")
        }
    }
}
