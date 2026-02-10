import Cocoa

class PasteService {
    static let shared = PasteService()
    private let pasteQueue = DispatchQueue(label: "com.voxlink.paste", qos: .userInteractive)
    
    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // 1. Update clipboard as a background backup (manual paste fallback)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("Clipboard updated. Starting Surgical Accessibility Injection...")
        
        // 2. Smart Injection Strategy
        // 2. Smart Injection Strategy
        pasteQueue.async {
            // A. Try Surgical Accessibility Injection first 
            // Internal logic now checks for "AXWebArea" role to fail fast for Electron apps.
            if self.injectTextViaAccessibility(text) {
                print("SUCCESS: Text injected surgically via Accessibility API.")
            } else {
                // B. Fallback to Menu Bar Paste (Required for AXWebArea or failure)
                print("Accessibility injection failed/skipped. Triggering Menu Bar Paste...")
                self.pasteViaMenuBar()
            }
        }
    }
    
    
    
    private func pasteViaMenuBar() {
        // 1. Get the frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier
        let accessibilityApp = AXUIElementCreateApplication(pid)
        
        // 2. Find the Menu Bar
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(accessibilityApp, kAXMenuBarAttribute as CFString, &menuBar)
        
        guard result == .success, let menuBarElement = menuBar as! AXUIElement? else {
            print("Fallback Failed: Could not find Menu Bar.")
            return
        }
        
        // 3. Find "Edit" -> "Paste"
        // This is a simplified traversal. For production, we might want to cache this or be more robust.
        if let editMenu = findMenu(in: menuBarElement, named: "Edit"),
           let pasteItem = findMenuItem(in: editMenu, named: "Paste") {
            
            print("Found 'Paste' menu item. Triggering AXPress...")
            let error = AXUIElementPerformAction(pasteItem, kAXPressAction as CFString)
            if error == .success {
                print("Fallback Success: AXPress triggered on Paste menu.")
            } else {
                print("Fallback Failed: AXPress returned error \(error.rawValue)")
            }
        } else {
            print("Fallback Failed: Could not find 'Edit' > 'Paste' menu item.")
        }
    }
    
    private func findMenu(in menuBar: AXUIElement, named name: String) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement] else { return nil }
        
        for item in items {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
            if let titleStr = title as? String, titleStr == name {
                return item
            }
        }
        return nil
    }
    
    private func findMenuItem(in menu: AXUIElement, named name: String) -> AXUIElement? {
        // Did we get the Menu Element or the Menu Item?
        // Usually Menu Item (Edit) -> Children (Menu) -> Children (Menu Items)
        
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }
        
        var subChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
        guard let subItems = subChildren as? [AXUIElement] else { return nil }
        
        for item in subItems {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
            if let titleStr = title as? String, titleStr == name {
                return item
            }
        }
        return nil
    }
    
    private func injectTextViaAccessibility(_ text: String) -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success, let element = focusedElement as! AXUIElement? else {
            return false
        }
        
        // 1. Check the Role of the focused element.
        // Electron apps (VSCode, Discord, Chrome) typically use "AXWebArea" or "AXGroup" for their text areas.
        // Native apps use "AXTextArea" or "AXTextField".
        // Direct injection (AXSelectedTextAttribute) often silently fails on AXWebArea.
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        var roleStr = "Unknown"
        if let roleVal = role as? String {
            roleStr = roleVal
            print("DEBUG: Focused Element Role: \(roleStr)")
            if roleStr == "AXWebArea" || roleStr == "AXGroup" {
                // Return false to start the "Menu Bar Paste" fallback immediately.
                // This is a GENERIC heuristic, not a hardcoded app list.
                return false
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
            return false
        }
        
        // B. VERIFY: Did the cursor move?
        usleep(1000) // 1ms
        
        let newRange = getSelectedRange(element: element)
        
        // C. Detection Logic:
        // If we had a range, and the new range is IDENTICAL, then the app ignored us.
        // Use strict check: if we *know* the range didn't move, fail.
        // If we couldn't get ranges, we assume SUCCESS (native app weirdness safe default).
        if let old = originalRange, let new = newRange {
            if old.location == new.location && old.length == new.length {
                print("DEBUG: Silent Failure Detected! Range didn't move. Role: \(roleStr)")
                return false // Trigger Fallback
            }
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






