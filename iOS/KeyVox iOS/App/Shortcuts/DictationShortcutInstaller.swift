import Foundation
import UIKit

enum DictationShortcutInstaller {
    static func openInstallation() async throws {
        guard let shortcutURL = Bundle.main.url(
            forResource: "Toggle KeyVox Dictation",
            withExtension: "shortcut"
        ) else {
            throw DictationShortcutInstallationError.missingBundledShortcut
        }

        guard await UIApplication.shared.open(shortcutURL) else {
            throw DictationShortcutInstallationError.unableToOpenShortcut
        }
    }
}

private enum DictationShortcutInstallationError: LocalizedError {
    case missingBundledShortcut
    case unableToOpenShortcut

    var errorDescription: String? {
        switch self {
        case .missingBundledShortcut:
            String(localized: "The KeyVox dictation shortcut is missing from this build.")
        case .unableToOpenShortcut:
            String(localized: "The KeyVox dictation shortcut could not be opened.")
        }
    }
}
