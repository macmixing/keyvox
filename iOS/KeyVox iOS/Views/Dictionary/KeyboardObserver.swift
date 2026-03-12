import Combine
import SwiftUI

final class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible = false

    private var willShowObserver: NSObjectProtocol?
    private var willHideObserver: NSObjectProtocol?

    init(center: NotificationCenter = .default) {
        willShowObserver = center.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardVisible = true
        }

        willHideObserver = center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardVisible = false
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
