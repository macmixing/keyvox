import Cocoa

protocol PasteAXInspecting {
    func prepareApplicationAccessibility(for pid: pid_t)
    func focusedInsertionContext() -> PasteInsertionContext?
    func focusedUIElement() -> AXUIElement?
    func roleString(for element: AXUIElement) -> String?
    func selectedRange(for element: AXUIElement) -> CFRange?
    func stringForRange(_ range: CFRange, element: AXUIElement) -> String?
    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character?
    func valueLengthForMenuVerification(element: AXUIElement) -> Int?
    func valueStringForMenuVerification(element: AXUIElement) -> String?
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement]
}

extension PasteAXInspecting {
    func prepareApplicationAccessibility(for pid: pid_t) {
        _ = pid
    }
}

final class PasteAXInspector: PasteAXInspecting {
    private let maxPreviousNonWhitespaceScanLength = 100
    private let accessibilityWarmupRetryCount = 5
    private let accessibilityWarmupRetryDelay: useconds_t = 50_000

    func prepareApplicationAccessibility(for pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        warmUpAccessibilityTree(app)
    }

    func focusedInsertionContext() -> PasteInsertionContext? {
        guard let focusedElement = focusedUIElement() else { return nil }

        // Best-effort context: selection/caret may be unavailable in some editors.
        let selectedRange = selectedRange(for: focusedElement)
        if isQuillBlankEditor(focusedElement) {
            #if DEBUG
            print("[PasteAXInspector] empty_editor_context source=AXDOMClassList class=ql-blank")
            #endif
            return PasteInsertionContext(
                selectionLength: 0,
                caretLocation: 0,
                previousCharacter: nil,
                previousNonWhitespaceCharacter: nil
            )
        }
        if isPlaceholderBackedEmptyEditor(focusedElement, selectedRange: selectedRange) {
            #if DEBUG
            print("[PasteAXInspector] empty_editor_context source=AXDOMClassList class=placeholder")
            #endif
            return PasteInsertionContext(
                selectionLength: 0,
                caretLocation: 0,
                previousCharacter: nil,
                previousNonWhitespaceCharacter: nil
            )
        }

        let caretLocation = selectedRange.map { max(0, $0.location) }
        let selectionLength = selectedRange.map { max(0, $0.length) }

        var previousCharacter: Character?
        var previousNonWhitespaceCharacter: Character?
        if let caretLocation, caretLocation > 0 {
            previousCharacter = previousCharacterFromValueAttribute(element: focusedElement, caretLocation: caretLocation)
            if previousCharacter == nil {
                previousCharacter = stringForRange(
                    CFRange(location: caretLocation - 1, length: 1),
                    element: focusedElement
                )?.first
            }

            previousNonWhitespaceCharacter = computePreviousNonWhitespaceCharacter(
                element: focusedElement,
                caretLocation: caretLocation
            )
        }

        return PasteInsertionContext(
            selectionLength: selectionLength,
            caretLocation: caretLocation,
            previousCharacter: previousCharacter,
            previousNonWhitespaceCharacter: previousNonWhitespaceCharacter
        )
    }

    func focusedUIElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusResult == .success, let focusedElementRef else { return nil }
        guard CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(focusedElementRef, to: AXUIElement.self)
    }

    func roleString(for element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else {
            return nil
        }
        return roleRef as? String
    }

    func selectedRange(for element: AXUIElement) -> CFRange? {
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

    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
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

    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? {
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

    private func computePreviousNonWhitespaceCharacter(
        element: AXUIElement,
        caretLocation: Int
    ) -> Character? {
        guard caretLocation > 0 else { return nil }

        if let value = valueString(for: element) {
            let nsValue = value as NSString
            let startingLocation = min(caretLocation, nsValue.length) - 1
            var candidateLocation = startingLocation
            while candidateLocation >= 0 {
                let candidate = nsValue.substring(with: NSRange(location: candidateLocation, length: 1))
                if let character = candidate.first, !character.isWhitespace {
                    return character
                }
                candidateLocation -= 1
            }
            return nil
        }

        var candidateLocation = caretLocation - 1
        var scannedCharacterCount = 0
        while candidateLocation >= 0 && scannedCharacterCount < maxPreviousNonWhitespaceScanLength {
            let candidate = stringForRange(
                CFRange(location: candidateLocation, length: 1),
                element: element
            )?.first
            if let candidate, !candidate.isWhitespace {
                return candidate
            }
            candidateLocation -= 1
            scannedCharacterCount += 1
        }

        return nil
    }

    private func valueString(for element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        )

        guard valueResult == .success, let value = valueRef as? String else { return nil }
        return value
    }

    private func isQuillBlankEditor(_ element: AXUIElement) -> Bool {
        guard roleString(for: element) == "AXTextArea" else { return false }

        var classListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXDOMClassList" as CFString, &classListRef) == .success,
              let classList = classListRef as? [String] else {
            return false
        }

        return Self.containsQuillBlankDOMClass(classList)
    }

    static func containsQuillBlankDOMClass(_ classList: [String]) -> Bool {
        classList.contains("ql-blank")
    }

    private func isPlaceholderBackedEmptyEditor(
        _ element: AXUIElement,
        selectedRange: CFRange?
    ) -> Bool {
        guard roleString(for: element) == "AXTextArea",
              selectedRange?.length == 0,
              let value = valueString(for: element),
              !value.isEmpty else {
            return false
        }

        let nsValue = value as NSString
        guard selectedRange?.location == nsValue.length else { return false }

        var classListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXDOMClassList" as CFString, &classListRef) == .success,
              let classList = classListRef as? [String] else {
            return false
        }

        return Self.containsPlaceholderDOMClass(classList)
    }

    static func containsPlaceholderDOMClass(_ classList: [String]) -> Bool {
        classList.contains("placeholder")
    }

    func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        guard let value = valueStringForMenuVerification(element: element) else { return nil }
        return (value as NSString).length
    }

    func valueStringForMenuVerification(element: AXUIElement) -> String? {
        valueString(for: element)
    }

    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int = 12,
        maxNodes: Int = 4_000,
        maxCandidates: Int = 12
    ) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        let initialCandidates = scanCandidateVerificationElements(
            app: app,
            maxDepth: maxDepth,
            maxNodes: maxNodes,
            maxCandidates: maxCandidates
        )
        guard initialCandidates.isEmpty else { return initialCandidates }

        warmUpAccessibilityTree(app)
        for _ in 0..<accessibilityWarmupRetryCount {
            usleep(accessibilityWarmupRetryDelay)
            let warmedCandidates = scanCandidateVerificationElements(
                app: app,
                maxDepth: maxDepth,
                maxNodes: maxNodes,
                maxCandidates: maxCandidates
            )
            if !warmedCandidates.isEmpty {
                return warmedCandidates
            }
        }

        return []
    }

    private func scanCandidateVerificationElements(
        app: AXUIElement,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        var roots: [AXUIElement] = []

        if let focusedWindow = elementAttribute(app, attribute: kAXFocusedWindowAttribute as String) {
            roots.append(focusedWindow)
        }

        roots.append(app)

        if let windows = elementsAttribute(app, attribute: kAXWindowsAttribute as String) {
            roots.append(contentsOf: windows)
        }

        var queue: [(element: AXUIElement, depth: Int)] = roots.map { ($0, 0) }
        var visited = Set<UInt>()
        var scanned = 0
        var out: [AXUIElement] = []

        while !queue.isEmpty && scanned < maxNodes && out.count < maxCandidates {
            let item = queue.removeFirst()
            let element = item.element
            let depth = item.depth

            let key = elementHash(element)
            if visited.contains(key) { continue }
            visited.insert(key)
            scanned += 1

            if isVerifiableTextTarget(element) {
                out.append(element)
                if out.count >= maxCandidates { break }
            }

            guard depth < maxDepth else { continue }
            for child in children(of: element) {
                queue.append((child, depth + 1))
            }
        }

        return out
    }

    private func warmUpAccessibilityTree(_ app: AXUIElement) {
        let manualAccessibilityAttribute = "AXManualAccessibility" as CFString
        let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface" as CFString
        let enabled = kCFBooleanTrue as CFTypeRef

        AXUIElementSetAttributeValue(app, manualAccessibilityAttribute, enabled)
        AXUIElementSetAttributeValue(app, enhancedUserInterfaceAttribute, enabled)

        _ = elementAttribute(app, attribute: kAXFocusedWindowAttribute as String)
        _ = elementsAttribute(app, attribute: kAXWindowsAttribute as String)
        _ = children(of: app)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func elementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref,
              CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(ref, to: AXUIElement.self)
    }

    private func elementsAttribute(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? [AXUIElement]
    }

    private func isVerifiableTextTarget(_ element: AXUIElement) -> Bool {
        let role = roleString(for: element)
        if role == "AXTextField" || role == "AXSearchField" || role == "AXTextArea" || role == "AXTextView" {
            return true
        }

        if boolAttribute(element, attribute: "AXEditable") == true {
            return true
        }

        let hasRange = selectedRange(for: element) != nil
        let hasValueLength = valueLengthForMenuVerification(element: element) != nil

        if (hasRange || hasValueLength) &&
            (isAttributeSettable(element, attribute: kAXSelectedTextAttribute as String) == true ||
             isAttributeSettable(element, attribute: kAXSelectedTextRangeAttribute as String) == true ||
             isAttributeSettable(element, attribute: kAXValueAttribute as String) == true) {
            return true
        }

        return false
    }

    private func boolAttribute(_ element: AXUIElement, attribute: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? Bool
    }

    private func isAttributeSettable(_ element: AXUIElement, attribute: String) -> Bool? {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success else {
            return nil
        }
        return settable.boolValue
    }

    private func elementHash(_ element: AXUIElement) -> UInt {
        return UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque())
    }
}
