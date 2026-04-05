import UIKit

final class KeyVoxShareAppLauncher {
    private let responderProvider: () -> UIResponder?

    init(responderProvider: @escaping () -> UIResponder?) {
        self.responderProvider = responderProvider
    }

    func open(_ url: URL?) {
        guard let url else { return }

        let modernSelector = NSSelectorFromString("openURL:options:completionHandler:")
        let legacySelector = NSSelectorFromString("openURL:")

        var responder = responderProvider()
        while let currentResponder = responder {
            if currentResponder.responds(to: modernSelector) {
                _ = currentResponder.perform(modernSelector, with: url, with: nil)
                return
            }

            if currentResponder.responds(to: legacySelector) {
                _ = currentResponder.perform(legacySelector, with: url)
                return
            }

            responder = currentResponder.next
        }
    }
}
