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
            return "Go"
        case .join:
            return "Join"
        case .route:
            return "Route"
        case .search, .google, .yahoo:
            return "Search"
        case .send:
            return "Send"
        case .done:
            return "Done"
        case .next:
            return "Next"
        case .continue:
            return "Continue"
        case .emergencyCall:
            return "Emergency Call"
        case .default:
            return "Return"
        @unknown default:
            return "Return"
        }
    }
}
