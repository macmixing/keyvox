import UIKit

@MainActor
enum DictationShortcutSettingsOpener {
    static func open() async -> Bool {
        guard let url = URL(string: "App-prefs:") else {
            return false
        }

        return await UIApplication.shared.open(url)
    }
}
