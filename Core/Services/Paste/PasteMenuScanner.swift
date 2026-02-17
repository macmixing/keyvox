import Cocoa

final class PasteMenuScanner {
    enum PasteItemLookupResult {
        case enabled(AXUIElement)
        case disabled
        case notFound
    }

    func findPasteItem(in menuItems: [AXUIElement]) -> PasteItemLookupResult {
        for menu in menuItems {
            if let pasteItem = findPasteMenuItem(in: menu) {
                if let isEnabled = menuItemEnabled(pasteItem), !isEnabled {
                    return .disabled
                }
                return .enabled(pasteItem)
            }
        }

        return .notFound
    }

    func findUndoItem(in menuItems: [AXUIElement]) -> AXUIElement? {
        for menu in menuItems {
            if let undoItem = findUndoMenuItem(in: menu) {
                return undoItem
            }
        }

        return nil
    }

    func menuItemTitle(_ item: AXUIElement) -> String? {
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }

    func menuItemEnabled(_ item: AXUIElement) -> Bool? {
        var enabled: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXEnabledAttribute as CFString, &enabled) == .success else {
            return nil
        }
        return enabled as? Bool
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
            if menuItemIdentifier(item) == "paste:" {
                return item
            }

            // 2) Cmd+V shortcut is locale-independent.
            if menuItemCmdChar(item) == "V" {
                return item
            }

            // 3) Title fallback for environments without identifier/shortcut metadata.
            if let title = menuItemTitle(item), title == "Paste" {
                return item
            }
        }
        return nil
    }

    private func findUndoMenuItem(in menu: AXUIElement) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }

        var subChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
        guard let subItems = subChildren as? [AXUIElement] else { return nil }

        for item in subItems {
            if menuItemIdentifier(item) == "undo:" {
                return item
            }

            if menuItemCmdChar(item)?.uppercased() == "Z" {
                let modifiers = menuItemCmdModifiers(item)
                let hasShiftModifier = (modifiers ?? 0) & 1 != 0
                let hasNoCommandModifier = (modifiers ?? 0) & 8 != 0
                if !hasShiftModifier && !hasNoCommandModifier {
                    return item
                }
            }

            if let title = menuItemTitle(item), title.hasPrefix("Undo") {
                return item
            }
        }

        return nil
    }

    private func menuItemIdentifier(_ item: AXUIElement) -> String? {
        var idValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &idValue) == .success else { return nil }
        return idValue as? String
    }

    private func menuItemCmdChar(_ item: AXUIElement) -> String? {
        var cmdChar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar) == .success,
              let charStr = cmdChar as? String else {
            return nil
        }
        return charStr
    }

    private func menuItemCmdModifiers(_ item: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &value) == .success else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }
}
