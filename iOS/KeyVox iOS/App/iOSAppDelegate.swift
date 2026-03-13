import UIKit

final class iOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            iOSAppServiceRegistry.shared.modelManager.handleBackgroundURLSessionEvents(
                identifier: identifier,
                completionHandler: completionHandler
            )
        }
    }
}
