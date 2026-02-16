#!/usr/bin/swift

import Cocoa
import ApplicationServices

struct Config {
    var appNames: [String] = ["Claude", "Codex", "Windsurf", "Cursor"]
    var maxDepth: Int = 32
    var maxNodes: Int = 80_000
    var topRoles: Int = 20
    var topCandidates: Int = 40
    var machine: Bool = true
    var allCandidates: Bool = true
    var prompt: Bool = false
}

struct NodeRecord {
    let root: String
    let path: String
    let depth: Int
    let role: String
    let subrole: String?
    let title: String?
    let desc: String?
    let identifier: String?
    let focused: Bool?
    let editable: Bool?
    let enabled: Bool?
    let selectedRange: CFRange?
    let selectedTextLength: Int?
    let valueLength: Int?
    let settableSelectedText: Bool?
    let settableSelectedRange: Bool?
    let settableValue: Bool?
}

struct RootScan {
    let rootLabel: String
    let fetchError: AXError
    let records: [NodeRecord]
}

enum AXAppsDump {
    static let strictRoles: Set<String> = [
        "AXTextField", "AXSearchField", "AXTextArea", "AXTextView", "AXComboBox"
    ]

    static func run() {
        let config = parseArgs()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: config.prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        print("Executable: \(CommandLine.arguments.first ?? "<unknown>")")
        print("AX Trusted: \(trusted ? "true" : "false")")
        print("Config: apps=\(config.appNames.joined(separator: ",")) depth=\(config.maxDepth) nodes=\(config.maxNodes) machine=\(config.machine) allCandidates=\(config.allCandidates)")

        guard trusted else {
            fputs("AX permission missing for this process. Use --prompt once and grant Accessibility.\n", stderr)
            exit(2)
        }

        let runningApps = NSWorkspace.shared.runningApplications
        for appName in config.appNames {
            let matches = runningApps.filter { app in
                guard let name = app.localizedName else { return false }
                return name.caseInsensitiveCompare(appName) == .orderedSame
            }

            guard !matches.isEmpty else {
                print("\n=== App: \(appName) ===")
                print("Status: not running")
                continue
            }

            for app in matches {
                report(app: app, config: config)
            }
        }
    }

    private static func report(app: NSRunningApplication, config: Config) {
        let name = app.localizedName ?? "<unknown>"
        let bundleID = app.bundleIdentifier ?? "<none>"
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        print("\n=== App: \(name) ===")
        print("Bundle ID: \(bundleID)")
        print("PID: \(pid)")
        print("Active: \(app.isActive)")
        print("Hidden: \(app.isHidden)")
        print("Terminated: \(app.isTerminated)")
        print("Paste Menu Enabled: \(pasteMenuEnabled(for: pid).map { $0 ? "true" : "false" } ?? "<nil>")")

        let focusedUI = probeElementAttribute(AXUIElementCreateSystemWide(), attribute: kAXFocusedUIElementAttribute as String)
        print("System FocusedUI AXError: \(axErrorString(focusedUI.error))")
        if let focused = focusedUI.element {
            var focusedPid: pid_t = 0
            AXUIElementGetPid(focused, &focusedPid)
            print("System FocusedUI PID: \(focusedPid) (matches app: \(focusedPid == pid))")
        } else {
            print("System FocusedUI: <none>")
        }

        let focusedWindow = probeElementAttribute(appElement, attribute: kAXFocusedWindowAttribute as String)
        let windows = probeElementsAttribute(appElement, attribute: kAXWindowsAttribute as String)

        let roots: [(String, AXError, AXUIElement?)] = [
            ("FocusedWindow", focusedWindow.error, focusedWindow.element),
            ("AppRoot", .success, appElement)
        ]

        var rootResults: [RootScan] = []
        for (label, fetchError, maybeRoot) in roots {
            guard let root = maybeRoot else {
                rootResults.append(RootScan(rootLabel: label, fetchError: fetchError, records: []))
                continue
            }
            let records = scanTree(from: root, rootLabel: label, maxDepth: config.maxDepth, maxNodes: config.maxNodes)
            rootResults.append(RootScan(rootLabel: label, fetchError: fetchError, records: records))
        }

        if windows.error == .success, let allWindows = windows.elements {
            for (idx, window) in allWindows.enumerated() {
                let label = "Window[\(idx)]"
                let records = scanTree(from: window, rootLabel: label, maxDepth: config.maxDepth, maxNodes: config.maxNodes)
                rootResults.append(RootScan(rootLabel: label, fetchError: .success, records: records))
            }
            print("AXWindows Count: \(allWindows.count)")
        } else {
            print("AXWindows AXError: \(axErrorString(windows.error))")
        }

        var globalStrict = 0
        for root in rootResults {
            printRoot(root, config: config)
            globalStrict += root.records.filter(isStrict).count
        }
        print("Global Strict Candidate Count: \(globalStrict)")
    }

    private static func printRoot(_ root: RootScan, config: Config) {
        print("\n-- Root: \(root.rootLabel) --")
        print("Root fetch AXError: \(axErrorString(root.fetchError))")

        if root.records.isEmpty {
            print("Scanned nodes: 0")
            return
        }

        print("Scanned nodes: \(root.records.count)")
        var roleCounts: [String: Int] = [:]
        for rec in root.records {
            roleCounts[rec.role, default: 0] += 1
        }
        let topRoles = roleCounts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }
        print("Top Roles:")
        for (role, count) in topRoles.prefix(config.topRoles) {
            print("  \(role): \(count)")
        }

        let strict = root.records.filter(isStrict)
        print("Strict Candidates: \(strict.count)")
        let slice = config.allCandidates ? strict : Array(strict.prefix(config.topCandidates))
        for (idx, rec) in slice.enumerated() {
            print(candidateLine(index: idx, record: rec))
        }

        if config.machine {
            for rec in strict {
                print(machineLine(record: rec))
            }
        }
    }

    private static func scanTree(from root: AXUIElement, rootLabel: String, maxDepth: Int, maxNodes: Int) -> [NodeRecord] {
        var queue: [(AXUIElement, Int, String)] = [(root, 0, "0")]
        var out: [NodeRecord] = []

        while !queue.isEmpty && out.count < maxNodes {
            let (element, depth, path) = queue.removeFirst()
            let range = cfRangeAttribute(element, kAXSelectedTextRangeAttribute as String)
            let value = stringAttribute(element, kAXValueAttribute as String)
            let selected = stringAttribute(element, kAXSelectedTextAttribute as String)

            out.append(NodeRecord(
                root: rootLabel,
                path: path,
                depth: depth,
                role: stringAttribute(element, kAXRoleAttribute as String) ?? "<nil>",
                subrole: stringAttribute(element, kAXSubroleAttribute as String),
                title: stringAttribute(element, kAXTitleAttribute as String),
                desc: stringAttribute(element, kAXDescriptionAttribute as String),
                identifier: stringAttribute(element, "AXIdentifier"),
                focused: boolAttribute(element, kAXFocusedAttribute as String),
                editable: boolAttribute(element, "AXEditable"),
                enabled: boolAttribute(element, kAXEnabledAttribute as String),
                selectedRange: range,
                selectedTextLength: selected?.count,
                valueLength: value?.count,
                settableSelectedText: isAttributeSettable(element, attribute: kAXSelectedTextAttribute as String),
                settableSelectedRange: isAttributeSettable(element, attribute: kAXSelectedTextRangeAttribute as String),
                settableValue: isAttributeSettable(element, attribute: kAXValueAttribute as String)
            ))

            guard depth < maxDepth else { continue }

            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for (idx, child) in children.enumerated() {
                    queue.append((child, depth + 1, "\(path).\(idx)"))
                }
            }
        }

        return out
    }

    private static func isStrict(_ rec: NodeRecord) -> Bool {
        strictRoles.contains(rec.role) || rec.editable == true
    }

    private static func candidateLine(index: Int, record: NodeRecord) -> String {
        "  [\(index)] root=\(record.root) path=\(record.path) depth=\(record.depth) role=\(record.role) subrole=\(record.subrole ?? "<nil>") focused=\(fmt(record.focused)) editable=\(fmt(record.editable)) enabled=\(fmt(record.enabled)) settable(ST,SR,V)=(\(fmt(record.settableSelectedText)),\(fmt(record.settableSelectedRange)),\(fmt(record.settableValue))) range=\(formatRange(record.selectedRange)) selectedLen=\(fmtInt(record.selectedTextLength)) valueLen=\(fmtInt(record.valueLength)) id=\(record.identifier ?? "<nil>") title=\(record.title ?? "<nil>") desc=\(record.desc ?? "<nil>")"
    }

    private static func machineLine(record: NodeRecord) -> String {
        let parts = [
            "kind=STRICT",
            "root=\(record.root)",
            "path=\(record.path)",
            "depth=\(record.depth)",
            "role=\(machineEscape(record.role))",
            "subrole=\(machineEscape(record.subrole ?? "<nil>"))",
            "focused=\(fmt(record.focused))",
            "editable=\(fmt(record.editable))",
            "enabled=\(fmt(record.enabled))",
            "settableSelectedText=\(fmt(record.settableSelectedText))",
            "settableSelectedRange=\(fmt(record.settableSelectedRange))",
            "settableValue=\(fmt(record.settableValue))",
            "range=\(machineEscape(formatRange(record.selectedRange)))",
            "selectedTextLen=\(fmtInt(record.selectedTextLength))",
            "valueLen=\(fmtInt(record.valueLength))",
            "id=\(machineEscape(record.identifier ?? "<nil>"))",
            "title=\(machineEscape(record.title ?? "<nil>"))",
            "desc=\(machineEscape(record.desc ?? "<nil>"))"
        ]
        return "MACHINE|\(parts.joined(separator: "|"))"
    }

    private static func parseArgs() -> Config {
        var config = Config()
        var i = 1
        while i < CommandLine.arguments.count {
            let arg = CommandLine.arguments[i]
            if arg == "--apps", i + 1 < CommandLine.arguments.count {
                let raw = CommandLine.arguments[i + 1]
                let names = raw
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !names.isEmpty { config.appNames = names }
                i += 2
                continue
            }
            if arg == "--max-depth", i + 1 < CommandLine.arguments.count, let v = Int(CommandLine.arguments[i + 1]) {
                config.maxDepth = max(1, v)
                i += 2
                continue
            }
            if arg == "--max-nodes", i + 1 < CommandLine.arguments.count, let v = Int(CommandLine.arguments[i + 1]) {
                config.maxNodes = max(1, v)
                i += 2
                continue
            }
            if arg == "--top-roles", i + 1 < CommandLine.arguments.count, let v = Int(CommandLine.arguments[i + 1]) {
                config.topRoles = max(1, v)
                i += 2
                continue
            }
            if arg == "--top-candidates", i + 1 < CommandLine.arguments.count, let v = Int(CommandLine.arguments[i + 1]) {
                config.topCandidates = max(1, v)
                i += 2
                continue
            }
            if arg == "--prompt" {
                config.prompt = true
                i += 1
                continue
            }
            if arg == "--machine" {
                config.machine = true
                i += 1
                continue
            }
            if arg == "--no-machine" {
                config.machine = false
                i += 1
                continue
            }
            if arg == "--all-candidates" {
                config.allCandidates = true
                i += 1
                continue
            }
            if arg == "--top-only" {
                config.allCandidates = false
                i += 1
                continue
            }
            i += 1
        }
        return config
    }

    private static func probeElementAttribute(_ element: AXUIElement, attribute: String) -> (error: AXError, element: AXUIElement?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return (result, nil)
        }
        return (result, unsafeBitCast(value, to: AXUIElement.self))
    }

    private static func probeElementsAttribute(_ element: AXUIElement, attribute: String) -> (error: AXError, elements: [AXUIElement]?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value, let array = value as? [AXUIElement] else {
            return (result, nil)
        }
        return (result, array)
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private static func cfRangeAttribute(_ element: AXUIElement, _ attribute: String) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let typed = axValue as! AXValue
        var range = CFRange()
        guard AXValueGetType(typed) == .cfRange, AXValueGetValue(typed, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private static func isAttributeSettable(_ element: AXUIElement, attribute: String) -> Bool? {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        guard result == .success else { return nil }
        return settable.boolValue
    }

    private static func pasteMenuEnabled(for pid: pid_t) -> Bool? {
        let app = AXUIElementCreateApplication(pid)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBarRef,
              CFGetTypeID(menuBarRef) == AXUIElementGetTypeID() else {
            return nil
        }

        let menuBar = unsafeBitCast(menuBarRef, to: AXUIElement.self)
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let menus = childrenRef as? [AXUIElement] else {
            return nil
        }

        for menu in menus {
            if let item = findPasteMenuItem(in: menu) {
                var enabledRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(item, kAXEnabledAttribute as CFString, &enabledRef) == .success else {
                    return nil
                }
                return enabledRef as? Bool
            }
        }

        return nil
    }

    private static func findPasteMenuItem(in menu: AXUIElement) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &childrenRef)
        guard let items = childrenRef as? [AXUIElement], let subMenu = items.first else { return nil }

        var subChildrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildrenRef)
        guard let subItems = subChildrenRef as? [AXUIElement] else { return nil }

        for item in subItems {
            var idRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &idRef) == .success,
               let id = idRef as? String, id == "paste:" {
                return item
            }

            var cmdRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdRef) == .success,
               let cmd = cmdRef as? String, cmd == "V" {
                return item
            }

            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, title == "Paste" {
                return item
            }
        }
        return nil
    }

    private static func fmt(_ value: Bool?) -> String {
        guard let value else { return "<nil>" }
        return value ? "true" : "false"
    }

    private static func fmtInt(_ value: Int?) -> String {
        guard let value else { return "<nil>" }
        return String(value)
    }

    private static func formatRange(_ range: CFRange?) -> String {
        guard let range else { return "<nil>" }
        return "\(range.location),\(range.length)"
    }

    private static func machineEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private static func axErrorString(_ error: AXError) -> String {
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
}

AXAppsDump.run()
