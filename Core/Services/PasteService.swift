import Cocoa

class PasteService {
    static let shared = PasteService()
    private let pasteQueue = DispatchQueue(label: "com.KeyVox.paste", qos: .userInteractive)

    private let heuristicTTL: TimeInterval = 10
    private var lastInsertionAppIdentity: AppIdentity?
    private var lastInsertionAt: Date = .distantPast
    private var lastInsertedTrailingCharacter: Character?

    private struct AppIdentity {
        let bundleID: String?
        let pid: pid_t
    }

    private struct InsertionContext {
        let focusedElement: AXUIElement
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

    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        let insertionText = applySmartLeadingSeparatorIfNeeded(to: text)
        let targetAppIdentity = frontmostAppIdentity()

        // 1. Save current clipboard state (lossless, item-based)
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

        // 2. Overwrite with new text (required for Cmd+V / menu-bar Paste fallback)
        pasteboard.clearContents()
        pasteboard.setString(insertionText, forType: .string)

        #if DEBUG
        print("Clipboard updated (Backup). Starting Surgical Accessibility Injection...")
        #endif

        // 3. Smart Injection Strategy
        pasteQueue.async {
            // A. Try Surgical Accessibility Injection first
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
                didAccessibilityInsertText = true
            case .failureNeedsFallback:
                needsMenuPasteFallback = true
                didAccessibilityInsertText = false
            }

            var didMenuPasteSucceed = false
            if needsMenuPasteFallback {
                #if DEBUG
                print("Accessibility injection failed/skipped. Triggering Menu Bar Paste...")
                #endif
                var textForMenuPaste = insertionText
                var didTypeLeadingSpaces = false

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
                    didMenuPasteSucceed = didTypeLeadingSpaces
                } else {
                    let didPaste = self.pasteViaMenuBarOnMainThread()
                    didMenuPasteSucceed = didPaste || didTypeLeadingSpaces
                }
            }

            if didAccessibilityInsertText || didMenuPasteSucceed {
                self.rememberSuccessfulInsertion(of: insertionText, in: targetAppIdentity)
            }

            // 4. Restore original clipboard after a short delay
            // - Accessibility injection doesn't need the clipboard for long.
            // - Menu Paste can be slower depending on the frontmost app.
            let restoreDelay: TimeInterval = needsMenuPasteFallback ? 0.8 : 0.25

            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                let pb = NSPasteboard.general
                pb.clearContents()

                // Rebuild original pasteboard items (preserves files, images, RTF, etc.)
                let itemsToWrite: [NSPasteboardItem] = savedSnapshot.map { itemDict in
                    let newItem = NSPasteboardItem()
                    for (type, data) in itemDict {
                        newItem.setData(data, forType: type)
                    }
                    return newItem
                }

                if !itemsToWrite.isEmpty {
                    let didWrite = pb.writeObjects(itemsToWrite)

                    // Hardening: `writeObjects` can be finicky in rare cases.
                    // If it fails, fall back to restoring the first item's types directly.
                    if !didWrite {
                        pb.clearContents()
                        if let first = savedSnapshot.first {
                            for (type, data) in first {
                                pb.setData(data, forType: type)
                            }
                        }
                    }
                }

                // Helpful debug signal
                let restoredCount = itemsToWrite.count
                #if DEBUG
                print("Clipboard state restored (items: \(restoredCount)).")
                #endif
            }
        }
    }

    private func applySmartLeadingSeparatorIfNeeded(to text: String) -> String {
        guard let firstIncoming = text.first else { return text }
        let context = focusedInsertionContext()

        // Replacing selected text should not auto-prefix a space.
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
        return " " + text
    }

    private func focusedInsertionContext() -> InsertionContext? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusResult == .success, let focusedElementRef else { return nil }
        let focusedElement = focusedElementRef as! AXUIElement

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
            focusedElement: focusedElement,
            selectionLength: selectionLength,
            caretLocation: caretLocation,
            previousCharacter: previousCharacter
        )
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

        // Insert a separator when starting a new dictation right after a word/sentence.
        return previousIsWordLike || previousIsTriggerPunctuation
    }

    private func pasteViaMenuBarOnMainThread() -> Bool {
        if Thread.isMainThread {
            return pasteViaMenuBar()
        }

        var didSucceed = false
        DispatchQueue.main.sync {
            didSucceed = pasteViaMenuBar()
        }
        return didSucceed
    }

    private func pasteViaMenuBar() -> Bool {
        // 1. Get the frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = frontApp.processIdentifier
        let accessibilityApp = AXUIElementCreateApplication(pid)

        // 2. Find the Menu Bar
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(accessibilityApp, kAXMenuBarAttribute as CFString, &menuBar)

        guard result == .success, menuBar != nil else {
            #if DEBUG
            print("Fallback Failed: Could not find Menu Bar.")
            #endif
            return false
        }

        let menuBarElement = menuBar as! AXUIElement

        // 3. Find "Paste" item in ANY menu (usually Edit, but we scan to be safe & locale-agnostic)
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children)
        guard let menuItems = children as? [AXUIElement] else { return false }

        for menu in menuItems {
            // Check if this menu contains the Paste item
            if let pasteItem = findPasteMenuItem(in: menu) {
                // Verify it's enabled before clicking
                var enabled: CFTypeRef?
                if AXUIElementCopyAttributeValue(pasteItem, kAXEnabledAttribute as CFString, &enabled) == .success,
                   let isEnabled = enabled as? Bool, !isEnabled {
                    #if DEBUG
                    print("Fallback Skipped: 'Paste' menu item is disabled (Context doesn't support pasting).")
                    #endif
                    return false
                }

                #if DEBUG
                print("Found 'Paste' menu item. Triggering AXPress...")
                #endif
                let error = AXUIElementPerformAction(pasteItem, kAXPressAction as CFString)
                if error == .success {
                    #if DEBUG
                    print("Fallback Success: AXPress triggered on Paste menu.")
                    #endif
                } else {
                    #if DEBUG
                    print("Fallback Failed: AXPress returned error \(error.rawValue)")
                    #endif
                }
                // Soft success: if Paste exists and is enabled, treat attempted AXPress
                // as success for insertion-memory continuity.
                return true
            }
        }

        #if DEBUG
        print("Fallback Failed: Could not find 'Paste' menu item in any menu.")
        #endif
        return false
    }

    private func findPasteMenuItem(in menu: AXUIElement) -> AXUIElement? {
        // Did we get the Menu Element or the Menu Item?
        // Usually Menu Item (Edit) -> Children (Menu) -> Children (Menu Items)

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }

        var subChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
        guard let subItems = subChildren as? [AXUIElement] else { return nil }

        for item in subItems {
            // 1. Check AXIdentifier (Most robust, usually "paste:")
            var idValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &idValue) == .success,
               let idStr = idValue as? String, idStr == "paste:" {
                return item
            }

            // 2. Check Cmd+V Shortcut (Locale independent)
            var cmdChar: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar) == .success,
               let charStr = cmdChar as? String, charStr == "V" {
                // Check modifiers if needed, but usually V is unique enough in Edit menu
                return item
            }

            // 3. Fallback: Title (English "Paste")
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
            if let titleStr = title as? String, titleStr == "Paste" {
                return item
            }
        }
        return nil
    }

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

        // 1. Check the Role of the focused element.
        // Electron apps (VSCode, Discord, Chrome) typically use "AXWebArea" or "AXGroup" for their text areas.
        // Native apps use "AXTextArea" or "AXTextField".
        // Direct injection (AXSelectedTextAttribute) often silently fails on AXWebArea.
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        var roleStr = "Unknown"
        if let roleVal = role as? String {
            roleStr = roleVal
            #if DEBUG
            print("DEBUG: Focused Element Role: \(roleStr)")
            #endif
            if roleStr == "AXWebArea" || roleStr == "AXGroup" {
                // Start the menu-bar paste fallback immediately.
                // This is a GENERIC heuristic, not a hardcoded app list.
                return .failureNeedsFallback
            }
        }

        // 2. Attempt Surgical Injection (Verification Mode)
        // Some Electron apps (like AntiGravity) report "AXTextArea" but silently fail.
        // We verify if the Selection Range moved (cursor advanced).

        let originalRange = getSelectedRange(element: element)

        // A. Try to set the value
        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if status != .success {
            return .failureNeedsFallback
        }

        // B. VERIFY: Did the cursor move?
        usleep(1000) // 1ms

        let newRange = getSelectedRange(element: element)

        // C. Detection Logic:
        // If we had a range, and the new range is IDENTICAL, then the app ignored us.
        // Treat this as "soft success": insertion may have happened, but we still fallback.
        if let old = originalRange, let new = newRange {
            if old.location == new.location && old.length == new.length {
                #if DEBUG
                print("DEBUG: Silent Failure Detected! Range didn't move. Role: \(roleStr)")
                #endif
                return .softSuccessNeedsFallback
            }
            return .verifiedSuccess
        }

        // Verification is inconclusive when range metadata is unavailable.
        // Keep soft success so we can seed spacing memory while still using fallback.
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

    private func getSelectedRange(element: AXUIElement) -> CFRange? {
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

        guard result == .success, let value = rangeValue else { return nil }

        // AXValue Check
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axVal = value as! AXValue
            var range = CFRange()
            // .cfRange is the type for kAXSelectedTextRangeAttribute
            if AXValueGetValue(axVal, .cfRange, &range) {
                return range
            }
        }
        return nil
    }
}
