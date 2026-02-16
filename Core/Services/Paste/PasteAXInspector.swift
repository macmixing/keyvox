import Cocoa

final class PasteAXInspector {
    // Ventura + some Electron apps can return stale/no AX data off the main thread.
    // Normalize AX reads onto main to keep focused element and verification stable.
    private func readAXOnMain<T>(_ block: () -> T) -> T {
        if Thread.isMainThread {
            return block()
        }

        var result: T!
        DispatchQueue.main.sync {
            result = block()
        }
        return result
    }

    func focusedInsertionContext() -> PasteInsertionContext? {
        guard let focusedElement = focusedUIElement() else { return nil }

        // Best-effort context: selection/caret may be unavailable in some editors.
        let selectedRange = selectedRange(for: focusedElement)
        let caretLocation = selectedRange.map { max(0, $0.location) }
        let selectionLength = selectedRange.map { max(0, $0.length) }

        var previousCharacter: Character?
        if let caretLocation, caretLocation > 0 {
            previousCharacter = previousCharacterFromValueAttribute(element: focusedElement, caretLocation: caretLocation)
            if previousCharacter == nil {
                previousCharacter = stringForRange(
                    CFRange(location: caretLocation - 1, length: 1),
                    element: focusedElement
                )?.first
            }
        }

        return PasteInsertionContext(
            selectionLength: selectionLength,
            caretLocation: caretLocation,
            previousCharacter: previousCharacter
        )
    }

    func focusedUIElement() -> AXUIElement? {
        readAXOnMain {
            if let element = focusedUIElementFromSystemWide() {
                return element
            }
            return focusedUIElementFromFrontmostApp()
        }
    }

    private func focusedUIElementFromSystemWide() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        guard result == .success else { return nil }
        return axElement(from: focusedElementRef)
    }

    private func focusedUIElementFromFrontmostApp() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // First try app-level focused element.
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        if focusedResult == .success, let focusedElement = axElement(from: focusedRef) {
            return focusedElement
        }

        // Then try focused window -> focused element.
        var focusedWindowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )
        guard windowResult == .success,
              let focusedWindow = axElement(from: focusedWindowRef) else {
            return nil
        }

        var windowFocusedRef: CFTypeRef?
        let windowFocusedResult = AXUIElementCopyAttributeValue(
            focusedWindow,
            kAXFocusedUIElementAttribute as CFString,
            &windowFocusedRef
        )
        guard windowFocusedResult == .success else { return nil }
        return axElement(from: windowFocusedRef)
    }

    private func axElement(from value: CFTypeRef?) -> AXUIElement? {
        guard let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    func roleString(for element: AXUIElement) -> String? {
        readAXOnMain {
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else {
                return nil
            }
            return roleRef as? String
        }
    }

    func selectedRange(for element: AXUIElement) -> CFRange? {
        readAXOnMain {
            var rangeValue: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

            guard result == .success, let value = rangeValue else { return nil }

            // kAXSelectedTextRangeAttribute is represented as AXValue(.cfRange).
            if CFGetTypeID(value) == AXValueGetTypeID() {
                let axVal = value as! AXValue
                var range = CFRange()
                if AXValueGetValue(axVal, .cfRange, &range) {
                    return range
                }
            }
            return nil
        }
    }

    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
        readAXOnMain {
            var safeRange = CFRange(location: max(0, range.location), length: max(0, range.length))
            guard let rangeValue = AXValueCreate(.cfRange, &safeRange) else { return nil }

            var valueRef: CFTypeRef?
            let result = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &valueRef
            )

            guard result == .success, let text = valueRef as? String else { return nil }
            return text
        }
    }

    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? {
        readAXOnMain {
            guard caretLocation > 0 else { return nil }

            var valueRef: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(
                element,
                kAXValueAttribute as CFString,
                &valueRef
            )

            guard valueResult == .success, let value = valueRef as? String else { return nil }
            let nsValue = value as NSString
            guard caretLocation <= nsValue.length else { return nil }

            let previousText = nsValue.substring(with: NSRange(location: caretLocation - 1, length: 1))
            return previousText.first
        }
    }

    func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        readAXOnMain {
            var valueRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
                  let value = valueRef as? String else {
                return nil
            }
            return (value as NSString).length
        }
    }
}
