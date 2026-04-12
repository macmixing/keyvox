import Combine
import SwiftUI

final class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible = false
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

        return max(0, frameValue.height)
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
