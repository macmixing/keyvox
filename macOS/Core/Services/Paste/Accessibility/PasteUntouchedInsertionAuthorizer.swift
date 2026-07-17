import ApplicationServices
import Foundation

final class PasteUntouchedInsertionAuthorizer {
    private struct PendingInsertion {
        let appIdentity: PasteAppIdentity
        let element: AXUIElement
    }

    private let axInspector: PasteAXInspecting
    private let replacer: PasteUntouchedInsertionReplacing
    private let appIdentityProvider: () -> PasteAppIdentity?
    private let pendingResolutionTimeout: TimeInterval
    private var token: PasteUntouchedInsertionToken?
    private var pendingInsertion: PendingInsertion?

    init(
        axInspector: PasteAXInspecting,
        replacer: PasteUntouchedInsertionReplacing,
        appIdentityProvider: @escaping () -> PasteAppIdentity?,
        pendingResolutionTimeout: TimeInterval
    ) {
        self.axInspector = axInspector
        self.replacer = replacer
        self.appIdentityProvider = appIdentityProvider
        self.pendingResolutionTimeout = pendingResolutionTimeout
    }

    func invalidate() {
        token = nil
        pendingInsertion = nil
    }

    func recordInsertion(_ text: String, appIdentity: PasteAppIdentity?) {
        token = captureToken(for: text, appIdentity: appIdentity)
        pendingInsertion = token == nil
            ? capturePendingInsertion(appIdentity: appIdentity)
            : nil
    }

    func authorization(for text: String) -> PasteUntouchedInsertionToken? {
        guard let token else {
            if pendingInsertion != nil {
                return resolvePendingInsertion(for: text)
            }
            return nil
        }
        guard let currentIdentity = appIdentityProvider(),
              currentIdentity.pid == token.appIdentity.pid,
              let currentTarget = replacer.target(for: text),
              let currentSelectedRange = axInspector.selectedRange(for: currentTarget.element),
              token.authorizes(
                  appIdentity: currentIdentity,
                  target: currentTarget,
                  selectedRange: currentSelectedRange
              ) else {
            self.token = nil
            return nil
        }
        return token
    }

    func recordReplacement(
        _ text: String,
        authorizedBy token: PasteUntouchedInsertionToken
    ) {
        pendingInsertion = nil
        guard let updatedToken = captureToken(
            for: text,
            appIdentity: token.appIdentity
        ), token.canAdvance(
            to: updatedToken.target,
            in: updatedToken.appIdentity
        ) else {
            self.token = nil
            return
        }
        let expectedSelection = CFRange(
            location: updatedToken.target.range.location + updatedToken.target.range.length,
            length: 0
        )
        self.token = PasteUntouchedInsertionToken(
            appIdentity: updatedToken.appIdentity,
            target: updatedToken.target,
            selectedRange: expectedSelection
        )
    }

    private func captureToken(
        for text: String,
        appIdentity: PasteAppIdentity?
    ) -> PasteUntouchedInsertionToken? {
        guard let appIdentity,
              let currentIdentity = appIdentityProvider(),
              currentIdentity.pid == appIdentity.pid,
              let target = replacer.target(for: text),
              let selectedRange = axInspector.selectedRange(for: target.element) else {
            return nil
        }
        return PasteUntouchedInsertionToken(
            appIdentity: appIdentity,
            target: target,
            selectedRange: selectedRange
        )
    }

    private func capturePendingInsertion(
        appIdentity: PasteAppIdentity?
    ) -> PendingInsertion? {
        guard let appIdentity,
              let currentIdentity = appIdentityProvider(),
              currentIdentity.pid == appIdentity.pid,
              let element = axInspector.focusedUIElement() else {
            return nil
        }
        return PendingInsertion(appIdentity: appIdentity, element: element)
    }

    private func resolvePendingInsertion(
        for text: String
    ) -> PasteUntouchedInsertionToken? {
        guard let pendingInsertion else { return nil }

        let timeout = Date().addingTimeInterval(pendingResolutionTimeout)
        var delay: useconds_t = 1_000
        repeat {
            guard let currentIdentity = appIdentityProvider(),
                  currentIdentity.pid == pendingInsertion.appIdentity.pid else {
                self.pendingInsertion = nil
                return nil
            }

            if let target = replacer.target(for: text) {
                guard CFEqual(target.element, pendingInsertion.element) else {
                    self.pendingInsertion = nil
                    return nil
                }
                if let selectedRange = axInspector.selectedRange(for: target.element) {
                    let resolvedToken = PasteUntouchedInsertionToken(
                        appIdentity: pendingInsertion.appIdentity,
                        target: target,
                        selectedRange: selectedRange
                    )
                    token = resolvedToken
                    self.pendingInsertion = nil
                    return resolvedToken
                }
            }

            guard Date() < timeout else { break }
            usleep(delay)
            delay = min(delay * 2, 16_000)
        } while true

        self.pendingInsertion = nil
        return nil
    }
}
