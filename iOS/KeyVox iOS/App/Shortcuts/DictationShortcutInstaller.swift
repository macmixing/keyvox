import Foundation
import UIKit

@MainActor
enum DictationShortcutInstaller {
    static func openInstallation() async throws {
        guard let shortcutURL = Bundle.main.url(
            forResource: "Toggle KeyVox Dictation",
            withExtension: "shortcut"
        ) else {
            throw DictationShortcutInstallationError.missingBundledShortcut
        }

        if #available(iOS 26.0, *) {
            guard await UIApplication.shared.open(shortcutURL) else {
                throw DictationShortcutInstallationError.shortcutsAppUnavailable
            }
            return
        }

        guard let presenter = activePresentationViewController else {
            throw DictationShortcutInstallationError.unableToOpenShortcut
        }

        let activityViewController = UIActivityViewController(
            activityItems: [shortcutURL],
            applicationActivities: nil
        )
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.sourceView = presenter.view
            popoverPresentationController.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
        }
        presenter.present(activityViewController, animated: true)
    }

    private static var activePresentationViewController: UIViewController? {
        topViewController(from: AppForegroundWindow.current?.rootViewController)
    }

    private static func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let presentedViewController = viewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        return viewController
    }
}

private enum DictationShortcutInstallationError: LocalizedError {
    case missingBundledShortcut
    case unableToOpenShortcut
    case shortcutsAppUnavailable

    var errorDescription: String? {
        switch self {
        case .missingBundledShortcut:
            String(localized: "The KeyVox dictation shortcut is missing from this build.", comment: "Error shown on the dictation shortcut setup screen when the bundled shortcut file is missing. KeyVox is a brand name and stays in English.")
        case .shortcutsAppUnavailable:
            String(localized: "Install the Shortcuts app from the App Store, then try adding the KeyVox dictation shortcut again.", comment: "Error shown on the dictation shortcut setup screen when the Shortcuts app is not installed. Use Apple's official names for the Shortcuts app and the App Store in this language. KeyVox is a brand name and stays in English.")
        case .unableToOpenShortcut:
            String(localized: "The KeyVox dictation shortcut could not be opened.", comment: "Error shown on the dictation shortcut setup screen when the shortcut could not be opened for installation. KeyVox is a brand name and stays in English.")
        }
    }
}
