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
                throw DictationShortcutInstallationError.unableToOpenShortcut
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
        let rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController
        return topViewController(from: rootViewController)
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

    var errorDescription: String? {
        switch self {
        case .missingBundledShortcut:
            String(localized: "The KeyVox dictation shortcut is missing from this build.")
        case .unableToOpenShortcut:
            String(localized: "The KeyVox dictation shortcut could not be opened.")
        }
    }
}
