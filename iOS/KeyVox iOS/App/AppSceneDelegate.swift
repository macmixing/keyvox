import UIKit

@MainActor
final class AppSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        let launchURL = connectionOptions.urlContexts.first?.url
        AppLaunchRouteStore.shared.resolveInitialLaunchURL(launchURL)
    }
}
