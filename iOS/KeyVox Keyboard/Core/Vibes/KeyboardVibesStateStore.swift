import Foundation
import KeyVoxStyleRewrite

final class KeyboardVibesStateStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)) {
        self.defaults = defaults
    }

    var selectedVibeTitle: String {
        selectedVibe.displayName
    }

    var isVibesAvailable: Bool {
        FoundationStyleRewriteAvailability.isAvailable
    }

    var selectedVibe: StyleRewriteStyle {
        guard let rawValue = defaults?.string(forKey: UserDefaultsKeys.selectedVibe),
              let style = StyleRewriteStyle(rawValue: rawValue) else {
            return .none
        }

        return style
    }

    @discardableResult
    func advance() -> String {
        let styles = StyleRewriteStyle.allCases
        guard styles.isEmpty == false else { return selectedVibe.displayName }
        let currentStyle = selectedVibe
        let currentIndex = styles.firstIndex(of: currentStyle) ?? 0
        let nextIndex = (currentIndex + 1) % styles.count
        let nextStyle = styles[nextIndex]
        defaults?.set(nextStyle.rawValue, forKey: UserDefaultsKeys.selectedVibe)
        KeyVoxIPCBridge.publishVibeSelectionChanged()
        return nextStyle.displayName
    }
}
