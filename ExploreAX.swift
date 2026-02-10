import Cocoa
import ApplicationServices

func exploreFrontmostApp() {
    let apps = NSWorkspace.shared.runningApplications
    for app in apps {
        print("App: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"))")
    }

    guard let app = apps.first(where: { $0.bundleIdentifier == "com.google.Chrome" }) else {
        print("Google Chrome (com.google.Chrome) not found running.")
        return
    }
    
    print("Frontmost App: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "No Bundle ID"))")
    let pid = app.processIdentifier
    let accessibilityApp = AXUIElementCreateApplication(pid)
    
    // 1. Get the Menu Bar with Retry
    var menuBar: CFTypeRef?
    var retries = 3
    while retries > 0 {
        let result = AXUIElementCopyAttributeValue(accessibilityApp, kAXMenuBarAttribute as CFString, &menuBar)
        if result == .success { break }
        print("Menu Bar lookup failed. Retrying... (\(retries))")
        Thread.sleep(forTimeInterval: 0.5)
        retries -= 1
    }
    
    guard let menuBarElement = menuBar as! AXUIElement? else {
        print("Could not find Menu Bar after retries.")
        // Fallback: Try to print all attributes to see what IS available
        var attrNames: CFArray?
        AXUIElementCopyAttributeNames(accessibilityApp, &attrNames)
        print("Available App Attributes: \(attrNames ?? [] as CFArray)")
        return
    }
    
    // 2. Find "Edit" Menu
    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children)
    
    guard let menuItems = children as? [AXUIElement] else { return }
    
    for item in menuItems {
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
        
        if let titleStr = title as? String, titleStr == "Edit" {
            print("Found 'Edit' Menu. Listing children...")
            exploreEditMenu(item)
            return
        }
    }
    
    print("'Edit' menu not found.")
}

func exploreEditMenu(_ editMenu: AXUIElement) {
    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(editMenu, kAXChildrenAttribute as CFString, &children)
    
    // The "Edit" menu item usually has a valid submenu child
    guard let items = children as? [AXUIElement], let subMenu = items.first else { return }
    
    // Get submenu children
    var subChildren: CFTypeRef?
    AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
    
    guard let subItems = subChildren as? [AXUIElement] else { return }
    
    for item in subItems {
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
        
        if let name = title as? String {
            print("- MenuItem: \(name)")
            if name == "Paste" {
                print("  -> FOUND PASTE! Checking attributes...")
                var attrNames: CFArray?
                AXUIElementCopyAttributeNames(item, &attrNames)
                if let names = attrNames as? [String] {
                    print("  -> Attributes: \(names)")
                    for attr in names {
                        var value: CFTypeRef?
                        AXUIElementCopyAttributeValue(item, attr as CFString, &value)
                        print("    - \(attr): \(value ?? "nil" as CFTypeRef)")
                    }
                }
            }
        }
    }
}

exploreFrontmostApp()
