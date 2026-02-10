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
        pasteQueue.async {
            // A. Check for "Problematic" Apps (Electron/Cross-Platform) that claim AX success but fail
            // Examples: VSCode, Discord, Slack, Cursor, Arc, etc.
            if self.shouldForceFallback() {
                print("App requires legacy paste (Electron/Web). Triggering Menu Bar Paste...")
                self.pasteViaMenuBar()
                return
            }
            
            // B. Try Surgical Accessibility Injection first (Fastest & Most Reliable for Native Apps)
            if self.injectTextViaAccessibility(text) {
                print("SUCCESS: Text injected surgically via Accessibility API.")
            } else {
                // C. Fallback to Menu Bar Paste (Required for any failure)
                print("Accessibility injection failed. Triggering Menu Bar Paste...")
                self.pasteViaMenuBar()
            }
        }
    }
    
    private func shouldForceFallback() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            return false
        }
        
        let lowerBundle = bundleID.lowercased()
        let knownProblemApps = [
            "code",       // VSCode (com.microsoft.VSCode)
            "cursor",     // Cursor AI
            "slack",      // Slack
            "discord",    // Discord
            "warp",       // Warp Terminal
            "electron",   // Generic Electron
            "todesktop",  // ToDesktop wrappers
            "arc",        // Arc Browser
            "chrome",     // Google Chrome (often AX is weird on specific fields)
            "brave",      // Brave Browser
            "firefox",    // Firefox
            "antigravity" // The User's IDE/App
        ]
        
        // If the bundle ID contains any of these strings, force fallback
        return knownProblemApps.contains { lowerBundle.contains($0) }
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
        
        // Find the currently focused UI element system-wide
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success, let element = focusedElement as! AXUIElement? else {
            print("Error: Could not find focused element via Accessibility.")
            return false
        }
        
        // Attempt to set the selected text attribute.
        // If selection is empty, this inserts at the cursor.
        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        
        return status == .success
    }
}






