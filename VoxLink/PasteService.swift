import Cocoa

class PasteService {
    static let shared = PasteService()
    
    func pasteText(_ text: String) {
        // No filters.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("Clipboard updated with transcription. Triggering Cmd+V...")
        
        // 0.2s delay to ensure the focused app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Using nil source for maximum global compatibility
            let source = CGEventSource(stateID: .hidSystemState)
            
            // Cmd Down (Flags must be added to the events that follow)
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
            
            // V Down
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            
            // V Up
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand
            
            // Cmd Up
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
            
            // Post events to HID level
            cmdDown?.post(tap: .cghidEventTap)
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
            
            print("Keystroke events posted.")
        }
    }
}
