import Cocoa

protocol PasteAXInspecting {
    func prepareApplicationAccessibility(for pid: pid_t)
    func focusedInsertionContext() -> PasteInsertionContext?
    func focusedUIElement() -> AXUIElement?
    func roleString(for element: AXUIElement) -> String?
    func selectedRange(for element: AXUIElement) -> CFRange?
    func selectedText(for element: AXUIElement) -> String?
    func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool
    func setSelectedText(_ text: String, for element: AXUIElement) -> Bool
    func setValueString(_ text: String, for element: AXUIElement) -> Bool
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

    func selectedText(for element: AXUIElement) -> String? {
        _ = element
        return nil
    }

    func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool {
        _ = range
        _ = element
        return false
    }

    func setSelectedText(_ text: String, for element: AXUIElement) -> Bool {
        _ = text
        _ = element
        return false
    }

    func setValueString(_ text: String, for element: AXUIElement) -> Bool {
        _ = text
        _ = element
        return false
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
        let focusedSelectedText: String? = if let selectedRange,
                                              selectedRange.length > 0 {
            selectedText(for: focusedElement)
                ?? stringForRange(selectedRange, element: focusedElement)
        } else {
            nil
        }

        var previousCharacter: Character?
        var characterBeforePreviousCharacter: Character?
        var previousNonWhitespaceCharacter: Character?
        var characterBeforePreviousNonWhitespaceCharacter: Character?
        var isPreviousNonWhitespaceCharacterAtLineStart = false
        if let caretLocation, caretLocation > 0 {
            if let precedingText = textBeforeCaret(
                element: focusedElement,
                caretLocation: caretLocation
            ) {
                let precedingCharacters = Array(precedingText)
                previousCharacter = precedingCharacters.last
                characterBeforePreviousCharacter = precedingCharacters.dropLast().last

                let precedingNonWhitespace = precedingCharacters.reversed().filter {
                    !$0.isWhitespace
                }
                previousNonWhitespaceCharacter = precedingNonWhitespace.first
                characterBeforePreviousNonWhitespaceCharacter = precedingNonWhitespace.dropFirst().first

                if let previousNonWhitespaceIndex = precedingCharacters.lastIndex(where: { !$0.isWhitespace }) {
                    var index = previousNonWhitespaceIndex - 1
                    while index >= 0, precedingCharacters[index].isWhitespace {
                        if precedingCharacters[index].unicodeScalars.allSatisfy(CharacterSet.newlines.contains) {
                            isPreviousNonWhitespaceCharacterAtLineStart = true
                            break
                        }
                        index -= 1
                    }
                }
            }
        }

        let context = PasteInsertionContext(
            selectionLength: selectionLength,
            selectedText: focusedSelectedText,
            caretLocation: caretLocation,
            previousCharacter: previousCharacter,
            characterBeforePreviousCharacter: characterBeforePreviousCharacter,
            previousNonWhitespaceCharacter: previousNonWhitespaceCharacter,
            characterBeforePreviousNonWhitespaceCharacter: characterBeforePreviousNonWhitespaceCharacter,
            isPreviousNonWhitespaceCharacterAtLineStart: isPreviousNonWhitespaceCharacterAtLineStart
        )
        #if DEBUG
        if ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1" {
            let caretDescription = caretLocation.map(String.init) ?? "-"
            print(
                "[PasteAXInspector] insertionContext "
                    + "caret=\(caretDescription) "
                    + "selectionLength=\(selectionLength.map(String.init) ?? "-") "
                    + "selectedText=\(String(reflecting: focusedSelectedText)) "
                    + "previous=\(String(reflecting: previousCharacter)) "
                    + "beforePrevious=\(String(reflecting: characterBeforePreviousCharacter)) "
                    + "previousNonWhitespace=\(String(reflecting: previousNonWhitespaceCharacter)) "
                    + "beforePreviousNonWhitespace=\(String(reflecting: characterBeforePreviousNonWhitespaceCharacter)) "
                    + "previousNonWhitespaceAtLineStart=\(isPreviousNonWhitespaceCharacterAtLineStart)"
            )
        }
        #endif
        return context
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

    func selectedText(for element: AXUIElement) -> String? {
        var textRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &textRef
        ) == .success else {
            return nil
        }

        return textRef as? String
    }

    func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        ) == .success
    }

    func setSelectedText(_ text: String, for element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        ) == .success
    }

    func setValueString(_ text: String, for element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        ) == .success
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
        textBeforeCaretFromValueAttribute(
            element: element,
            caretLocation: caretLocation
        )?.last
    }

    private func textBeforeCaret(element: AXUIElement, caretLocation: Int) -> String? {
        guard caretLocation > 0 else { return nil }
        let startLocation = max(0, caretLocation - maxPreviousNonWhitespaceScanLength)
        if let rangeText = stringForRange(
            CFRange(location: startLocation, length: caretLocation - startLocation),
            element: element
        ), rangeText.isEmpty == false {
            let rangeAfterCaret = stringForRange(
                CFRange(location: caretLocation, length: 1),
                element: element
            )
            let value = valueString(for: element)
            let insertionLine = integerAttribute(
                kAXInsertionPointLineNumberAttribute as String,
                element: element
            )
            let caretIndexLine = lineForIndex(caretLocation, element: element)
            let shouldTreatTrailingNewline = Self.shouldTreatNewlineRangeAtCaret(
                rangeAfterCaret,
                rangeText: rangeText,
                value: value,
                caretLocation: caretLocation,
                insertionLine: insertionLine,
                caretIndexLine: caretIndexLine
            )
                || (value.map {
                    Self.shouldTreatTrailingValueNewlineAsPrecedingCaret(
                        rangeText: rangeText,
                        value: $0,
                        caretLocation: caretLocation
                    )
                } ?? false)
            if shouldTreatTrailingNewline {
                return rangeText + "\n"
            }
            return rangeText
        }

        return textBeforeCaretFromValueAttribute(
            element: element,
            caretLocation: caretLocation
        )
    }

    private func integerAttribute(_ attribute: String, element: AXUIElement) -> Int? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &valueRef
        ) == .success,
        let number = valueRef as? NSNumber else {
            return nil
        }
        return number.intValue
    }

    private func lineForIndex(_ index: Int, element: AXUIElement) -> Int? {
        let indexNumber = NSNumber(value: index)
        var lineRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXLineForIndex" as CFString,
            indexNumber,
            &lineRef
        ) == .success,
        let number = lineRef as? NSNumber else {
            return nil
        }
        return number.intValue
    }

    static func isNewlineRangeAtCaret(_ rangeAfterCaret: String?) -> Bool {
        guard let rangeAfterCaret, rangeAfterCaret.isEmpty == false else { return false }
        return rangeAfterCaret.unicodeScalars.allSatisfy(CharacterSet.newlines.contains)
    }

    static func shouldTreatNewlineRangeAtCaret(
        _ rangeAfterCaret: String?,
        rangeText: String? = nil,
        value: String? = nil,
        caretLocation: Int? = nil,
        insertionLine: Int?,
        caretIndexLine: Int?
    ) -> Bool {
        guard isNewlineRangeAtCaret(rangeAfterCaret),
              let insertionLine,
              let caretIndexLine else {
            return false
        }
        if let rangeText,
           let value,
           let caretLocation,
           valueConfirmsNewlineFollowsCaret(
               rangeText: rangeText,
               value: value,
               caretLocation: caretLocation
           ) {
            return false
        }
        return insertionLine == caretIndexLine
    }

    private static func valueConfirmsNewlineFollowsCaret(
        rangeText: String,
        value: String,
        caretLocation: Int
    ) -> Bool {
        guard rangeText.isEmpty == false,
              caretLocation >= 0,
              caretLocation < value.utf16.count else {
            return false
        }

        let valueBeforeCaret = String(
            decoding: value.utf16.prefix(caretLocation),
            as: UTF16.self
        )
        let valueAfterCaret = String(
            decoding: value.utf16.dropFirst(caretLocation),
            as: UTF16.self
        )
        return valueBeforeCaret.hasSuffix(rangeText)
            && valueAfterCaret.first?.unicodeScalars.allSatisfy(CharacterSet.newlines.contains) == true
    }

    static func shouldTreatTrailingValueNewlineAsPrecedingCaret(
        rangeText: String,
        value: String,
        caretLocation: Int?
    ) -> Bool {
        guard let caretLocation,
              caretLocation >= 0,
              rangeText.last?.unicodeScalars.allSatisfy(CharacterSet.newlines.contains) == false,
              value.last?.unicodeScalars.allSatisfy(CharacterSet.newlines.contains) == true else {
            return false
        }

        let valueLengthWithoutNewlines = value.reduce(into: 0) { length, character in
            if character.unicodeScalars.allSatisfy(CharacterSet.newlines.contains) == false {
                length += String(character).utf16.count
            }
        }
        return caretLocation == valueLengthWithoutNewlines
    }

    private func textBeforeCaretFromValueAttribute(
        element: AXUIElement,
        caretLocation: Int
    ) -> String? {
        guard caretLocation > 0,
              let value = valueString(for: element) else {
            return nil
        }

        let safeCaretLocation = min(caretLocation, value.utf16.count)
        return String(decoding: value.utf16.prefix(safeCaretLocation), as: UTF16.self)
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
