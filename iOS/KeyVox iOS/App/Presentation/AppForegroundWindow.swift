import UIKit

/// KeyVox's window: the key window of its scene in the foreground.
@MainActor
enum AppForegroundWindow {
    static var current: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }
}
