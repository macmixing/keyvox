import Cocoa

class PasteService {
    static let shared = PasteService()
    // Serialize insertion side effects (AX writes, menu fallback, clipboard restore scheduling).
    private let pasteQueue = DispatchQueue(label: "com.KeyVox.paste", qos: .userInteractive)

    // Heuristic memory for consecutive dictation when AX metadata is incomplete.
    private let heuristicTTL: TimeInterval = 10
    private let restoreDelayAfterMenuFallback: TimeInterval = 0.8
    private let restoreDelayAfterAccessibilityInjection: TimeInterval = 0.25
    private let menuFallbackVerificationTimeout: TimeInterval = 0.6
    private let menuFallbackVerificationPollInterval: TimeInterval = 0.05
    private var lastInsertionAppIdentity: AppIdentity?
    private var lastInsertionAt: Date = .distantPast
    private var lastInsertedTrailingCharacter: Character?

    private struct AppIdentity {
        let bundleID: String?
        let pid: pid_t
    }

    private struct InsertionContext {
        let selectionLength: Int?
        let caretLocation: Int?
        let previousCharacter: Character?
    }

    private enum AccessibilityInjectionOutcome {
        case verifiedSuccess
        case softSuccessNeedsFallback
        case failureNeedsFallback
    }

    private struct MenuFallbackTransport {
        let leadingSpacesToType: Int
        let textToPaste: String
    }

    private enum MenuFallbackAttemptResult {
        case unavailable
        case actionSucceeded
        case actionErrored
    }

    private struct MenuFallbackVerificationContext {
        let element: AXUIElement
        let selectedRange: CFRange?
        let valueLength: Int?
    }

    // MARK: - Entry Point
    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        cancelActiveRecoveryOnMainThread()

        let insertionText = applySmartLeadingSeparatorIfNeeded(to: text)
        let targetAppIdentity = frontmostAppIdentity()

        // Preserve full clipboard fidelity before writing insertion payload.
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems ?? []
        let savedSnapshot: [[NSPasteboard.PasteboardType: Data]] = savedItems.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }

        // Menu fallback uses Cmd+V semantics, so payload must be in the clipboard.
        pasteboard.clearContents()
        pasteboard.setString(insertionText, forType: .string)

        #if DEBUG
        print("Clipboard updated (Backup). Starting Surgical Accessibility Injection...")
        #endif

        pasteQueue.async {
            let injectionOutcome = self.injectTextViaAccessibility(insertionText)
            let needsMenuPasteFallback: Bool
            let didAccessibilityInsertText: Bool

            switch injectionOutcome {
            case .verifiedSuccess:
                needsMenuPasteFallback = false
                didAccessibilityInsertText = true
                #if DEBUG
                print("SUCCESS: Text injected surgically via Accessibility API.")
                #endif
            case .softSuccessNeedsFallback:
                needsMenuPasteFallback = true
                didAccessibilityInsertText = false
            case .failureNeedsFallback:
                needsMenuPasteFallback = true
                didAccessibilityInsertText = false
            }

            var didMenuFallbackInsert = false
            if needsMenuPasteFallback {
                #if DEBUG
                print("Accessibility injection failed/skipped. Triggering Menu Bar Paste...")
                #endif
                var textForMenuPaste = insertionText
                var didTypeLeadingSpaces = false
                let verificationContext = self.captureMenuFallbackVerificationContext()

                // Some apps normalize leading spaces on paste. If AX injection fully failed,
                // type leading spaces as key events, then paste the remaining text.
                if !didAccessibilityInsertText {
                    let transport = self.menuFallbackTransport(for: insertionText)
                    textForMenuPaste = transport.textToPaste

                    if transport.leadingSpacesToType > 0 {
                        didTypeLeadingSpaces = self.typeLeadingSpacesOnMainThread(count: transport.leadingSpacesToType)
                    }
                }

                if textForMenuPaste != insertionText {
                    self.setClipboardStringOnMainThread(textForMenuPaste)
                }

                if textForMenuPaste.isEmpty {
                    didMenuFallbackInsert = didTypeLeadingSpaces
                } else {
                    switch self.pasteViaMenuBarOnMainThread() {
                    case .unavailable:
                        didMenuFallbackInsert = false
                    case .actionSucceeded:
                        if self.shouldTrustMenuSuccessWithoutAXVerification() {
                            // Some apps (notably iMessage) can retarget Paste to the composer even
                            // when the currently focused AX element is not the final insertion target.
                            didMenuFallbackInsert = true
                        } else {
                            // Even when AXPress reports success, verify resulting AX state when possible
                            // so we can catch no-op "successful" actions in apps like browser-based editors.
                            didMenuFallbackInsert = self.verifyMenuFallbackInsertion(using: verificationContext)
                        }
                    case .actionErrored:
                        didMenuFallbackInsert = self.verifyMenuFallbackInsertion(using: verificationContext)
                    }
                }
            }

            if didAccessibilityInsertText || didMenuFallbackInsert {
                self.rememberSuccessfulInsertion(of: insertionText, in: targetAppIdentity)
            }

            if !Self.shouldStartFailureRecovery(
                didAccessibilityInsertText: didAccessibilityInsertText,
                didMenuFallbackInsert: didMenuFallbackInsert
            ) {
                // Menu-driven paste can complete slightly after AX calls.
                let restoreDelay: TimeInterval = needsMenuPasteFallback ? self.restoreDelayAfterMenuFallback : self.restoreDelayAfterAccessibilityInjection
                self.restoreClipboardOnMainThread(from: savedSnapshot, delay: restoreDelay)
            } else {
                self.startFailureRecoveryOnMainThread(savedSnapshot: savedSnapshot)
            }
        }
    }

    // MARK: - List Formatting Target
    func preferredListRenderModeForFocusedElement() -> ListRenderMode {
        guard let focusedElement = focusedUIElement(),
              let role = roleString(for: focusedElement) else {
            return .multiline
        }

        let bundleID = frontmostAppIdentity()?.bundleID
        return Self.listRenderMode(forAXRole: role, bundleID: bundleID)
    }

    static func listRenderMode(forAXRole role: String?) -> ListRenderMode {
        listRenderMode(forAXRole: role, bundleID: nil)
    }

    static func listRenderMode(forAXRole role: String?, bundleID: String?) -> ListRenderMode {
        // Some apps expose message composers as single-line roles even when newline insertion is valid.
        if let bundleID, multilineListOverrideBundleIDs.contains(bundleID) {
            return .multiline
        }

        guard let role else { return .multiline }

        switch role {
        case "AXTextField", "AXSearchField", "AXComboBox":
            return .singleLineInline
        default:
            return .multiline
        }
    }

    private static let multilineListOverrideBundleIDs: Set<String> = [
        "com.apple.MobileSMS"
    ]

    private static let menuSuccessTrustWithoutAXVerificationBundleIDs: Set<String> = [
        "com.apple.MobileSMS"
    ]

    private func shouldTrustMenuSuccessWithoutAXVerification() -> Bool {
        guard let bundleID = frontmostAppIdentity()?.bundleID else { return false }
        return Self.menuSuccessTrustWithoutAXVerificationBundleIDs.contains(bundleID)
    }

    // MARK: - Smart Spacing
    private func applySmartLeadingSeparatorIfNeeded(to text: String) -> String {
        guard let firstIncoming = text.first else { return text }
        let context = focusedInsertionContext()

        // Replacements should not auto-prefix a separator.
        if let context {
            if let selectionLength = context.selectionLength, selectionLength > 0 {
                return text
            }

            if let caretLocation = context.caretLocation, caretLocation == 0 {
                return text
            }

            if let previous = context.previousCharacter {
                guard shouldInsertLeadingSpace(previous: previous, firstIncoming: firstIncoming) else {
                    return text
                }
                return " " + text
            }
        }

        guard shouldInsertLeadingSpaceFromHeuristic(firstIncoming: firstIncoming) else {
            return text
        }
        // Best-effort fallback when AX context cannot provide a previous character.
        return " " + text
    }

    private func focusedInsertionContext() -> InsertionContext? {
        guard let focusedElement = focusedUIElement() else { return nil }

        // Best-effort context: selection/caret may be unavailable in some editors.
        let selectedRange = getSelectedRange(element: focusedElement)
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

        return InsertionContext(
            selectionLength: selectionLength,
            caretLocation: caretLocation,
            previousCharacter: previousCharacter
        )
    }

    private func focusedUIElement() -> AXUIElement? {
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

    private func roleString(for element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else {
            return nil
        }
        return roleRef as? String
    }

    private func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? {
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

    private func shouldInsertLeadingSpaceFromHeuristic(firstIncoming: Character) -> Bool {
        guard let previous = lastInsertedTrailingCharacter else { return false }
        guard Date().timeIntervalSince(lastInsertionAt) <= heuristicTTL else { return false }
        guard let currentIdentity = frontmostAppIdentity(),
              let lastIdentity = lastInsertionAppIdentity,
              appIdentityMatches(currentIdentity, lastIdentity) else {
            return false
        }

        return shouldInsertLeadingSpace(previous: previous, firstIncoming: firstIncoming)
    }

    private func shouldInsertLeadingSpace(previous: Character, firstIncoming: Character) -> Bool {
        if firstIncoming.isWhitespace { return false }
        if previous.isWhitespace { return false }

        // If incoming text starts with punctuation, do not prefix a space.
        let incomingPunctuation = CharacterSet(charactersIn: ".,!?;:)]}\"'”’")
        if firstIncoming.unicodeScalars.allSatisfy({ incomingPunctuation.contains($0) }) {
            return false
        }

        // If we are immediately after an opening delimiter, do not prefix.
        if "([{".contains(previous) {
            return false
        }

        let spacingTriggerPunctuation = CharacterSet(charactersIn: ".,!?;:)]}\"'”’")
        let previousIsWordLike = previous.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        let previousIsTriggerPunctuation = previous.unicodeScalars.contains { spacingTriggerPunctuation.contains($0) }

        // Start a new dictation segment after a word/sentence boundary.
        return previousIsWordLike || previousIsTriggerPunctuation
    }

    // MARK: - Menu Fallback
    private func pasteViaMenuBarOnMainThread() -> MenuFallbackAttemptResult {
        if Thread.isMainThread {
            return pasteViaMenuBar()
        }

        var outcome: MenuFallbackAttemptResult = .unavailable
        DispatchQueue.main.sync {
            outcome = pasteViaMenuBar()
        }
        return outcome
    }

    private func pasteViaMenuBar() -> MenuFallbackAttemptResult {
        // 1. Get the frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return .unavailable }
        let pid = frontApp.processIdentifier
        let accessibilityApp = AXUIElementCreateApplication(pid)

        // 2. Find the Menu Bar
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(accessibilityApp, kAXMenuBarAttribute as CFString, &menuBar)

        guard result == .success, menuBar != nil else {
            #if DEBUG
            print("Fallback Failed: Could not find Menu Bar.")
            #endif
            return .unavailable
        }

        let menuBarElement = menuBar as! AXUIElement

        // Find "Paste" in any menu so this remains locale/layout resilient.
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children)
        guard let menuItems = children as? [AXUIElement] else { return .unavailable }

        for menu in menuItems {
            if let pasteItem = findPasteMenuItem(in: menu) {
                // Skip contexts where Paste exists but is currently disabled.
                var enabled: CFTypeRef?
                if AXUIElementCopyAttributeValue(pasteItem, kAXEnabledAttribute as CFString, &enabled) == .success,
                   let isEnabled = enabled as? Bool, !isEnabled {
                    #if DEBUG
                    print("Fallback Skipped: 'Paste' menu item is disabled (Context doesn't support pasting).")
                    #endif
                    return .unavailable
                }

                #if DEBUG
                print("Found 'Paste' menu item. Triggering AXPress...")
                #endif
                let error = AXUIElementPerformAction(pasteItem, kAXPressAction as CFString)
                if error == .success {
                    #if DEBUG
                    print("Fallback Success: AXPress triggered on Paste menu.")
                    #endif
                    return .actionSucceeded
                } else {
                    #if DEBUG
                    print("Fallback Warning: AXPress returned error \(error.rawValue). Verifying resulting text state...")
                    #endif
                    return .actionErrored
                }
            }
        }

        #if DEBUG
        print("Fallback Failed: Could not find 'Paste' menu item in any menu.")
        #endif
        return .unavailable
    }

    private func findPasteMenuItem(in menu: AXUIElement) -> AXUIElement? {
        // Expected structure: menu bar item -> submenu -> actionable menu entries.

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }

        var subChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
        guard let subItems = subChildren as? [AXUIElement] else { return nil }

        for item in subItems {
            // 1) AXIdentifier is the most stable signal when present.
            var idValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &idValue) == .success,
               let idStr = idValue as? String, idStr == "paste:" {
                return item
            }

            // 2) Cmd+V shortcut is locale-independent.
            var cmdChar: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar) == .success,
               let charStr = cmdChar as? String, charStr == "V" {
                return item
            }

            // 3) Title fallback for environments without identifier/shortcut metadata.
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
            if let titleStr = title as? String, titleStr == "Paste" {
                return item
            }
        }
        return nil
    }

    private func captureMenuFallbackVerificationContext() -> MenuFallbackVerificationContext? {
        guard let element = focusedUIElement() else { return nil }
        return MenuFallbackVerificationContext(
            element: element,
            selectedRange: getSelectedRange(element: element),
            valueLength: valueLengthForMenuVerification(element: element)
        )
    }

    private func verifyMenuFallbackInsertion(using context: MenuFallbackVerificationContext?) -> Bool {
        // If we cannot inspect AX state at all, avoid false "paste failed" overlays.
        guard let context else { return true }

        let initialRange = context.selectedRange
        let initialLength = context.valueLength

        var sawObservableAXState = (initialRange != nil || initialLength != nil)
        let deadline = Date().addingTimeInterval(menuFallbackVerificationTimeout)

        while Date() < deadline {
            let currentRange = getSelectedRange(element: context.element)
            let currentLength = valueLengthForMenuVerification(element: context.element)

            if currentRange != nil || currentLength != nil {
                sawObservableAXState = true
            }

            if let oldRange = initialRange, let currentRange {
                if oldRange.location != currentRange.location || oldRange.length != currentRange.length {
                    return true
                }
            }

            if let oldLength = initialLength, let currentLength, oldLength != currentLength {
                return true
            }

            usleep(useconds_t(menuFallbackVerificationPollInterval * 1_000_000))
        }

        // AX metadata is often unavailable in some editors; treat inconclusive checks as success
        // to prevent false recovery prompts after a successful visible paste.
        return !sawObservableAXState
    }

    private func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String else {
            return nil
        }
        return (value as NSString).length
    }

    // MARK: - Accessibility Injection
    private func injectTextViaAccessibility(_ text: String) -> AccessibilityInjectionOutcome {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, focusedElement != nil else {
            return .failureNeedsFallback
        }

        let element = focusedElement as! AXUIElement

        // Role gate: AXWebArea/AXGroup commonly ignore direct selected-text writes.
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        var roleStr = "Unknown"
        if let roleVal = role as? String {
            roleStr = roleVal
            #if DEBUG
            print("DEBUG: Focused Element Role: \(roleStr)")
            #endif
            if roleStr == "AXWebArea" || roleStr == "AXGroup" {
                // Generic fallback, not app-specific branching.
                return .failureNeedsFallback
            }
        }

        // Attempt direct selected-text write and verify range movement when available.
        let originalRange = getSelectedRange(element: element)

        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if status != .success {
            return .failureNeedsFallback
        }

        // Verify whether the caret/selection range changed after write.
        usleep(1000) // 1ms

        let newRange = getSelectedRange(element: element)

        // Identical ranges imply probable no-op; keep soft success and still fallback.
        if let old = originalRange, let new = newRange {
            if old.location == new.location && old.length == new.length {
                #if DEBUG
                print("DEBUG: Silent Failure Detected! Range didn't move. Role: \(roleStr)")
                #endif
                return .softSuccessNeedsFallback
            }
            return .verifiedSuccess
        }

        // Inconclusive verification: keep soft success and still run fallback path.
        return .softSuccessNeedsFallback
    }

    private func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
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

    // MARK: - Heuristic Identity / Memory
    private func frontmostAppIdentity() -> AppIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let rawBundleID = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = (rawBundleID?.isEmpty == false) ? rawBundleID : nil
        return AppIdentity(bundleID: bundleID, pid: app.processIdentifier)
    }

    private func appIdentityMatches(_ lhs: AppIdentity, _ rhs: AppIdentity) -> Bool {
        if let lhsBundleID = lhs.bundleID, let rhsBundleID = rhs.bundleID {
            return lhsBundleID == rhsBundleID
        }
        return lhs.pid == rhs.pid
    }

    private func rememberSuccessfulInsertion(of text: String, in appIdentity: AppIdentity?) {
        lastInsertionAppIdentity = appIdentity
        lastInsertionAt = Date()
        lastInsertedTrailingCharacter = text.last
    }

    private func cancelActiveRecoveryOnMainThread() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                PasteFailureRecoveryCoordinator.shared.cancelActiveRecoveryIfNeeded()
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                PasteFailureRecoveryCoordinator.shared.cancelActiveRecoveryIfNeeded()
            }
        }
    }

    private func startFailureRecoveryOnMainThread(
        savedSnapshot: [[NSPasteboard.PasteboardType: Data]]
    ) {
        let restoreClosure = { [savedSnapshot] in
            Self.restoreClipboardSnapshot(savedSnapshot)
        }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                PasteFailureRecoveryCoordinator.shared.startRecovery(restoreClipboard: restoreClosure)
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                PasteFailureRecoveryCoordinator.shared.startRecovery(restoreClipboard: restoreClosure)
            }
        }
    }

    private func restoreClipboardOnMainThread(
        from savedSnapshot: [[NSPasteboard.PasteboardType: Data]],
        delay: TimeInterval
    ) {
        let restoreBlock = { [savedSnapshot] in
            Self.restoreClipboardSnapshot(savedSnapshot)
        }

        if Thread.isMainThread {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreBlock)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreBlock)
    }

    private static func restoreClipboardSnapshot(
        _ savedSnapshot: [[NSPasteboard.PasteboardType: Data]]
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Restore original clipboard items (files, images, rich text, etc.).
        let itemsToWrite: [NSPasteboardItem] = savedSnapshot.map { itemDict in
            let newItem = NSPasteboardItem()
            for (type, data) in itemDict {
                newItem.setData(data, forType: type)
            }
            return newItem
        }

        if !itemsToWrite.isEmpty {
            let didWrite = pasteboard.writeObjects(itemsToWrite)

            // Rare fallback path when writeObjects fails.
            if !didWrite {
                pasteboard.clearContents()
                if let first = savedSnapshot.first {
                    for (type, data) in first {
                        pasteboard.setData(data, forType: type)
                    }
                }
            }
        }

        #if DEBUG
        print("Clipboard state restored (items: \(itemsToWrite.count)).")
        #endif
    }

    static func shouldStartFailureRecovery(
        didAccessibilityInsertText: Bool,
        didMenuFallbackInsert: Bool
    ) -> Bool {
        !didAccessibilityInsertText && !didMenuFallbackInsert
    }

    // MARK: - Menu Transport
    private func menuFallbackTransport(for text: String) -> MenuFallbackTransport {
        let leadingSpaces = text.prefix { $0 == " " }.count
        guard leadingSpaces > 0 else {
            return MenuFallbackTransport(leadingSpacesToType: 0, textToPaste: text)
        }

        let remainingText = String(text.dropFirst(leadingSpaces))
        return MenuFallbackTransport(leadingSpacesToType: leadingSpaces, textToPaste: remainingText)
    }

    private func setClipboardStringOnMainThread(_ text: String) {
        if Thread.isMainThread {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return
        }

        DispatchQueue.main.sync {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }

    private func typeLeadingSpacesOnMainThread(count: Int) -> Bool {
        if Thread.isMainThread {
            return typeLeadingSpaces(count: count)
        }

        var didSucceed = false
        DispatchQueue.main.sync {
            didSucceed = typeLeadingSpaces(count: count)
        }
        return didSucceed
    }

    private func typeLeadingSpaces(count: Int) -> Bool {
        guard count > 0 else { return true }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        for _ in 0..<count {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false) else {
                return false
            }
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }

    // MARK: - AX Utilities
    private func getSelectedRange(element: AXUIElement) -> CFRange? {
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
