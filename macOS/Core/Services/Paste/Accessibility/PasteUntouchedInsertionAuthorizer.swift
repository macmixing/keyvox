import Foundation

final class PasteUntouchedInsertionAuthorizer {
    private let axInspector: PasteAXInspecting
    private let replacer: PasteUntouchedInsertionReplacing
    private let appIdentityProvider: () -> PasteAppIdentity?
    private var token: PasteUntouchedInsertionToken?

    init(
        axInspector: PasteAXInspecting,
        replacer: PasteUntouchedInsertionReplacing,
        appIdentityProvider: @escaping () -> PasteAppIdentity?
    ) {
        self.axInspector = axInspector
        self.replacer = replacer
        self.appIdentityProvider = appIdentityProvider
    }

    func invalidate() {
        token = nil
    }

    func recordInsertion(_ text: String, appIdentity: PasteAppIdentity?) {
        token = captureToken(for: text, appIdentity: appIdentity)
    }

    func authorization(for text: String) -> PasteUntouchedInsertionToken? {
        guard let token,
              let currentIdentity = appIdentityProvider(),
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
        self.token = updatedToken
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
}
