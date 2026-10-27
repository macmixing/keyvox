import Combine
import SwiftUI

final class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible = false
    /// How much of KeyVox's window the keyboard covers: its whole height when the window reaches
    /// the bottom of the screen, less or none when the window ends above the keyboard on iPad.
    @Published var keyboardHeight: CGFloat = 0

    private var willShowObserver: NSObjectProtocol?
    private var willHideObserver: NSObjectProtocol?

    init(center: NotificationCenter = .default) {
        willShowObserver = center.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.isKeyboardVisible = true
            self?.keyboardHeight = Self.keyboardHeight(from: notification)
        }

        willHideObserver = center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardVisible = false
            self?.keyboardHeight = 0
        }
    }

    private static func keyboardHeight(from notification: Notification) -> CGFloat {
        guard let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }

        return MainActor.assumeIsolated {
            guard let window = AppForegroundWindow.current else {
                return max(0, frameValue.height)
            }
            // The keyboard's frame is in screen coordinates.
            let frameInWindow = window.convert(frameValue, from: window.screen.coordinateSpace)
            return max(0, window.bounds.maxY - frameInWindow.minY)
        }
    }

    deinit {
        let center = NotificationCenter.default

        if let willShowObserver {
            center.removeObserver(willShowObserver)
        }

        if let willHideObserver {
            center.removeObserver(willHideObserver)
        }
    }
}
