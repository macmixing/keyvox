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
        
        // 2. Surgical Injection (The Wispr Flow Way)
        pasteQueue.async {
            if self.injectTextViaAccessibility(text) {
                print("SUCCESS: Text injected surgically via Accessibility API.")
            } else {
                print("FAILED: Accessibility injection failed. Ensure Accessibility permissions are granted.")
            }
        }
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






