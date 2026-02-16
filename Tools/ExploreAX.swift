#!/usr/bin/env swift

import Cocoa
import ApplicationServices

struct Options {
    var bundleID: String?
    var useFrontmost = false
    var showMenu = true
    var maxAncestors = 6
}

func parseOptions() -> Options {
    var options = Options()
    var i = 1
    let args = CommandLine.arguments

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--bundle":
            if i + 1 < args.count {
                options.bundleID = args[i + 1]
                i += 1
            }
        case "--frontmost":
            options.useFrontmost = true
        case "--no-menu":
            options.showMenu = false
        case "--max-ancestors":
            if i + 1 < args.count, let value = Int(args[i + 1]) {
                options.maxAncestors = max(1, value)
                i += 1
            }
        case "--help", "-h":
            printUsageAndExit()
        default:
            break
        }
        i += 1
    }
    return options
}

func printUsageAndExit() -> Never {
    let script = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
    print("""
    Usage:
      \(script) --frontmost
      \(script) --bundle com.example.app

    Options:
      --frontmost           Target the current frontmost app.
      --bundle <id>         Target app by bundle identifier.
      --no-menu             Skip menu exploration.
      --max-ancestors <n>   Ancestor depth for focused element (default: 6).
      --help                Show this help.
    """)
    exit(0)
}

func axErrorName(_ error: AXError) -> String {
    switch error {
    case .success: return "success"
    case .failure: return "failure"
    case .illegalArgument: return "illegalArgument"
    case .invalidUIElement: return "invalidUIElement"
    case .invalidUIElementObserver: return "invalidUIElementObserver"
    case .cannotComplete: return "cannotComplete"
    case .attributeUnsupported: return "attributeUnsupported"
    case .actionUnsupported: return "actionUnsupported"
    case .notificationUnsupported: return "notificationUnsupported"
    case .notImplemented: return "notImplemented"
    case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
    case .notificationNotRegistered: return "notificationNotRegistered"
    case .apiDisabled: return "apiDisabled"
    case .noValue: return "noValue"
    case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
    case .notEnoughPrecision: return "notEnoughPrecision"
    @unknown default: return "unknown(\(error.rawValue))"
    }
}

func copyAttribute(_ element: AXUIElement, _ name: String) -> (AXError, CFTypeRef?) {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return (error, value)
}

func copyAttributeNames(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    let result = AXUIElementCopyAttributeNames(element, &names)
    guard result == .success, let array = names as? [String] else { return [] }
    return array
}

func copyActionNames(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    let result = AXUIElementCopyActionNames(element, &names)
    guard result == .success, let array = names as? [String] else { return [] }
    return array
}

func asElement(_ value: CFTypeRef?) -> AXUIElement? {
    value as! AXUIElement?
}

func cfValueString(_ value: CFTypeRef?) -> String {
    guard let value else { return "nil" }

    if CFGetTypeID(value) == AXUIElementGetTypeID() {
        return "<AXUIElement>"
    }
    if let s = value as? String { return s }
    if let n = value as? NSNumber { return n.stringValue }
    if let b = value as? Bool { return b ? "true" : "false" }
    if let a = value as? [Any] { return "Array(count=\(a.count))" }

    if CFGetTypeID(value) == AXValueGetTypeID() {
        let axValue = value as! AXValue
        let type = AXValueGetType(axValue)
        switch type {
        case .cfRange:
            var range = CFRange()
            if AXValueGetValue(axValue, .cfRange, &range) {
                return "CFRange(location=\(range.location), length=\(range.length))"
            }
        case .cgPoint:
            var point = CGPoint.zero
            if AXValueGetValue(axValue, .cgPoint, &point) {
                return "CGPoint(x=\(point.x), y=\(point.y))"
            }
        case .cgSize:
            var size = CGSize.zero
            if AXValueGetValue(axValue, .cgSize, &size) {
                return "CGSize(width=\(size.width), height=\(size.height))"
            }
        case .cgRect:
            var rect = CGRect.zero
            if AXValueGetValue(axValue, .cgRect, &rect) {
                return "CGRect(x=\(rect.origin.x), y=\(rect.origin.y), w=\(rect.size.width), h=\(rect.size.height))"
            }
        default:
            break
        }
        return "<AXValue type=\(type.rawValue)>"
    }
    return String(describing: value)
}

func describeElement(_ element: AXUIElement, label: String) {
    print("\n[\(label)]")
    let interestingAttributes = [
        kAXRoleAttribute,
        kAXSubroleAttribute,
        kAXTitleAttribute,
        kAXDescriptionAttribute,
        kAXIdentifierAttribute,
        kAXValueAttribute,
        kAXEnabledAttribute,
        kAXFocusedAttribute,
        kAXSelectedTextAttribute,
        kAXSelectedTextRangeAttribute,
        kAXPlaceholderValueAttribute
    ]

    let names = Set(copyAttributeNames(element))
    print("supportedAttributes=\(names.count), supportedActions=\(copyActionNames(element))")

    for key in interestingAttributes where names.contains(key) {
        let (result, value) = copyAttribute(element, key)
        print("  \(key): [\(axErrorName(result))] \(cfValueString(value))")
    }
}

func printAncestorChain(from element: AXUIElement, maxDepth: Int) {
    var current: AXUIElement? = element
    var depth = 0
    while let node = current, depth < maxDepth {
        describeElement(node, label: "FocusedChain depth=\(depth)")
        let (_, parentValue) = copyAttribute(node, kAXParentAttribute)
        current = asElement(parentValue)
        depth += 1
    }
}

func targetApplication(options: Options) -> NSRunningApplication? {
    if let bundle = options.bundleID {
        return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundle })
    }
    if options.useFrontmost {
        return NSWorkspace.shared.frontmostApplication
    }
    return nil
}

func printSystemFocus() -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    let (result, focusedValue) = copyAttribute(systemWide, kAXFocusedUIElementAttribute)
    let element = asElement(focusedValue)
    print("\n[SystemWide]")
    print("focusedUIElement result=\(axErrorName(result)) hasValue=\(element != nil)")
    return element
}

func printAppFocus(_ appElement: AXUIElement) -> AXUIElement? {
    let (focusedResult, focusedValue) = copyAttribute(appElement, kAXFocusedUIElementAttribute)
    let focused = asElement(focusedValue)
    print("\n[App]")
    print("focusedUIElement result=\(axErrorName(focusedResult)) hasValue=\(focused != nil)")

    let (windowResult, windowValue) = copyAttribute(appElement, kAXFocusedWindowAttribute)
    let window = asElement(windowValue)
    print("focusedWindow result=\(axErrorName(windowResult)) hasValue=\(window != nil)")
    return focused ?? window
}

func firstMenuItem(named targetName: String, inMenu menu: AXUIElement) -> AXUIElement? {
    let (_, childrenValue) = copyAttribute(menu, kAXChildrenAttribute)
    guard let children = childrenValue as? [AXUIElement] else { return nil }
    for child in children {
        let (_, titleValue) = copyAttribute(child, kAXTitleAttribute)
        if let title = titleValue as? String, title == targetName {
            return child
        }
    }
    return nil
}

func menuChildren(_ item: AXUIElement) -> [AXUIElement] {
    let (_, childrenValue) = copyAttribute(item, kAXChildrenAttribute)
    guard let firstLayer = childrenValue as? [AXUIElement], let first = firstLayer.first else { return [] }
    let (_, subChildrenValue) = copyAttribute(first, kAXChildrenAttribute)
    return (subChildrenValue as? [AXUIElement]) ?? []
}

func printMenuDiagnostics(_ appElement: AXUIElement) {
    let (menuResult, menuValue) = copyAttribute(appElement, kAXMenuBarAttribute)
    guard menuResult == .success, let menuBar = asElement(menuValue) else {
        print("\n[Menu] menuBar result=\(axErrorName(menuResult))")
        return
    }

    print("\n[Menu]")
    if let editItem = firstMenuItem(named: "Edit", inMenu: menuBar) {
        print("Found Edit menu")
        let items = menuChildren(editItem)
        print("Edit child count=\(items.count)")

        for item in items {
            let (_, titleValue) = copyAttribute(item, kAXTitleAttribute)
            let (_, enabledValue) = copyAttribute(item, kAXEnabledAttribute)
            let (_, cmdCharValue) = copyAttribute(item, kAXMenuItemCmdCharAttribute)
            let title = (titleValue as? String) ?? "<no-title>"
            let enabled = cfValueString(enabledValue)
            let cmdChar = cfValueString(cmdCharValue)
            print("  title=\(title), enabled=\(enabled), cmdChar=\(cmdChar)")

            if title == "Paste" {
                describeElement(item, label: "Edit->Paste")
            }
        }
    } else {
        print("Edit menu not found")
    }
}

func main() {
    let options = parseOptions()

    guard AXIsProcessTrusted() else {
        print("Accessibility permission is not granted for this process.")
        print("Enable Terminal (or your shell host) in System Settings -> Privacy & Security -> Accessibility.")
        exit(1)
    }

    guard let app = targetApplication(options: options) else {
        print("No target app found. Use --frontmost or --bundle <bundle-id>.")
        exit(1)
    }

    guard let bundle = app.bundleIdentifier else {
        print("Target app has no bundle identifier.")
        exit(1)
    }

    print("Target app: \(app.localizedName ?? "Unknown") bundle=\(bundle) pid=\(app.processIdentifier)")
    let appElement = AXUIElementCreateApplication(app.processIdentifier)

    let systemFocused = printSystemFocus()
    let appFocused = printAppFocus(appElement)
    let anchor = appFocused ?? systemFocused

    if let anchor {
        printAncestorChain(from: anchor, maxDepth: options.maxAncestors)
    } else {
        print("\nNo focused element available from system-wide or app-level AX.")
    }

    if options.showMenu {
        printMenuDiagnostics(appElement)
    }
}

main()
