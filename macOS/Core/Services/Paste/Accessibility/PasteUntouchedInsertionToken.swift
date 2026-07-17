import ApplicationServices

struct PasteUntouchedInsertionToken {
    let appIdentity: PasteAppIdentity
    let target: PasteUntouchedInsertionTarget
    let selectedRange: CFRange

    func authorizes(
        appIdentity: PasteAppIdentity,
        target: PasteUntouchedInsertionTarget,
        selectedRange: CFRange
    ) -> Bool {
        appIdentity.pid == self.appIdentity.pid
            && matchesElement(target.element)
            && matchesRange(target.range, expected: self.target.range)
            && matchesRange(selectedRange, expected: self.selectedRange)
    }

    func canAdvance(
        to target: PasteUntouchedInsertionTarget,
        in appIdentity: PasteAppIdentity
    ) -> Bool {
        appIdentity.pid == self.appIdentity.pid
            && matchesElement(target.element)
            && target.range.location == self.target.range.location
    }

    private func matchesElement(_ element: AXUIElement) -> Bool {
        CFEqual(target.element, element)
    }

    private func matchesRange(_ range: CFRange, expected: CFRange) -> Bool {
        range.location == expected.location && range.length == expected.length
    }
}
