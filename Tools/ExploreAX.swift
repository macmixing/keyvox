#!/usr/bin/swift

import Cocoa
import ApplicationServices

struct AXDumpConfig {
    var maxDepth: Int = 14
    var maxNodes: Int = 6000
    var topRoles: Int = 20
    var topCandidates: Int = 30
    var machineOutput: Bool = false
    var includeAllCandidates: Bool = false
}

struct AXNodeRecord {
    let element: AXUIElement
    let rootKind: RootKind
    let path: String
    let depth: Int
    let role: String
    let subrole: String?
    let title: String?
    let description: String?
    let identifier: String?
    let focused: Bool?
    let editable: Bool?
    let enabled: Bool?
    let selectedRange: CFRange?
    let selectedTextLength: Int?
    let valueLength: Int?
    let hasSelectedRange: Bool
    let hasValueString: Bool
    let settableSelectedText: Bool?
    let settableSelectedRange: Bool?
    let settableValue: Bool?
    let attrs: [String]
}

enum RootKind: String {
    case focusedWindow = "FocusedWindow"
    case appRoot = "AppRoot"
}

struct AXRootResult {
    let kind: RootKind
    let fetchError: AXError
    let root: AXUIElement?
    let records: [AXNodeRecord]
}

struct AXDump {
    static let strictTextRoles: Set<String> = [
        "AXTextField", "AXSearchField", "AXTextArea", "AXTextView", "AXComboBox"
    ]

    static func run() {
        let config = parseConfig()

        let shouldPrompt = CommandLine.arguments.contains("--prompt")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: shouldPrompt] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        print("Executable: \(CommandLine.arguments.first ?? "<unknown>")")
        print("Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("AX Trusted: \(isTrusted ? "true" : "false")")
        print("Config: depth=\(config.maxDepth) nodes=\(config.maxNodes) topRoles=\(config.topRoles) topCandidates=\(config.topCandidates)")

        guard isTrusted else {
            fputs("AX permission missing for this process. Run with --prompt or grant it in System Settings > Privacy & Security > Accessibility.\n", stderr)
            exit(2)
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            print("No frontmost application.")
            return
        }

        let appName = frontmost.localizedName ?? "<unknown>"
        let bundleID = frontmost.bundleIdentifier ?? "<none>"
        let pid = frontmost.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        print("Frontmost app: \(appName)")
        print("Bundle ID: \(bundleID)")
        print("PID: \(pid)")
        print("Paste Menu Enabled: \(pasteMenuEnabled(for: pid).map { $0 ? "true" : "false" } ?? "<nil>")")

        let focusedUIProbe = probeAXElementAttribute(AXUIElementCreateSystemWide(), attribute: kAXFocusedUIElementAttribute as String)
        print("FocusedUIElement AXError: \(axErrorString(focusedUIProbe.error))")
        if focusedUIProbe.element == nil {
            print("Focused element: <none>")
        }

        let focusedWindowProbe = probeAXElementAttribute(appElement, attribute: kAXFocusedWindowAttribute as String)
        let roots = [
            AXRootResult(kind: .focusedWindow, fetchError: focusedWindowProbe.error, root: focusedWindowProbe.element, records: []),
            AXRootResult(kind: .appRoot, fetchError: .success, root: appElement, records: [])
        ]

        var scannedRoots: [AXRootResult] = []
        for rootInfo in roots {
            guard let root = rootInfo.root else {
                scannedRoots.append(rootInfo)
                continue
            }
            let records = scanTree(from: root, rootKind: rootInfo.kind, maxDepth: config.maxDepth, maxNodes: config.maxNodes)
            scannedRoots.append(AXRootResult(kind: rootInfo.kind, fetchError: rootInfo.fetchError, root: root, records: records))
        }

        for rootResult in scannedRoots {
            report(rootResult, config: config)
        }

        let strictTotal = scannedRoots.flatMap(\ .records).filter { isStrictTextCandidate($0) }.count
        let looseTotal = scannedRoots.flatMap(\ .records).filter { isLooseWritableCandidate($0) }.count
        print("Global Strict Text Candidates: \(strictTotal)")
        print("Global Loose Writable Candidates: \(looseTotal)")

        if strictTotal == 0 {
            print("CLUE: No strict AX text-target candidates detected in frontmost app tree.")
        }
    }

    static func parseConfig() -> AXDumpConfig {
        var config = AXDumpConfig()
        var i = 1
        while i < CommandLine.arguments.count {
            let arg = CommandLine.arguments[i]
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
            if arg == "--machine" {
                config.machineOutput = true
                i += 1
                continue
            }
            if arg == "--all-candidates" {
                config.includeAllCandidates = true
                i += 1
                continue
            }
            i += 1
        }
        return config
    }

    static func report(_ result: AXRootResult, config: AXDumpConfig) {
        print("\n=== Root: \(result.kind.rawValue) ===")
        print("Root fetch AXError: \(axErrorString(result.fetchError))")
        guard result.root != nil else {
            print("Root element: <none>")
            return
        }

        let records = result.records
        print("Scanned nodes: \(records.count)")

        var roleCounts: [String: Int] = [:]
        for r in records {
            roleCounts[r.role, default: 0] += 1
        }
        let sortedRoles = roleCounts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        print("Top Roles:")
        for (role, count) in sortedRoles.prefix(config.topRoles) {
            print("  \(role): \(count)")
        }

        let strict = records.filter { isStrictTextCandidate($0) }
        let loose = records.filter { isLooseWritableCandidate($0) }
        print("Strict Text Candidates: \(strict.count)")
        print("Loose Writable Candidates: \(loose.count)")

        if !strict.isEmpty {
            print("Strict Candidate Details:")
            let strictSlice = config.includeAllCandidates ? Array(strict) : Array(strict.prefix(config.topCandidates))
            for (idx, c) in strictSlice.enumerated() {
                print(candidateLine(index: idx, record: c))
            }
            if config.machineOutput {
                print("Strict Candidate Machine Lines:")
                for c in strict {
                    print(machineLine(kind: "STRICT", record: c))
                }
            }
        }

        if !loose.isEmpty {
            print("Loose Candidate Details (non-strict only):")
            let looseOnly = loose.filter { !isStrictTextCandidate($0) }
            let looseSlice = config.includeAllCandidates ? Array(looseOnly) : Array(looseOnly.prefix(config.topCandidates))
            for (idx, c) in looseSlice.enumerated() {
                print(candidateLine(index: idx, record: c))
            }
            if config.machineOutput {
                print("Loose Candidate Machine Lines:")
                for c in looseOnly {
                    print(machineLine(kind: "LOOSE", record: c))
                }
            }
        }
    }

    static func candidateLine(index: Int, record: AXNodeRecord) -> String {
        let range = formatRange(record.selectedRange)
        return "  [\(index)] root=\(record.rootKind.rawValue) path=\(record.path) depth=\(record.depth) role=\(record.role) subrole=\(record.subrole ?? "<nil>") focused=\(fmt(record.focused)) editable=\(fmt(record.editable)) enabled=\(fmt(record.enabled)) settable(ST,SR,V)=(\(fmt(record.settableSelectedText)),\(fmt(record.settableSelectedRange)),\(fmt(record.settableValue))) hasRange=\(record.hasSelectedRange ? "true" : "false") range=\(range) selectedTextLen=\(fmtInt(record.selectedTextLength)) hasValue=\(record.hasValueString ? "true" : "false") valueLen=\(fmtInt(record.valueLength)) id=\(record.identifier ?? "<nil>") title=\(record.title ?? "<nil>") desc=\(record.description ?? "<nil>")"
    }

    static func machineLine(kind: String, record: AXNodeRecord) -> String {
        let range = formatRange(record.selectedRange)
        let parts = [
            "kind=\(kind)",
            "root=\(record.rootKind.rawValue)",
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
            "hasRange=\(record.hasSelectedRange ? "true" : "false")",
            "range=\(machineEscape(range))",
            "selectedTextLen=\(fmtInt(record.selectedTextLength))",
            "hasValue=\(record.hasValueString ? "true" : "false")",
            "valueLen=\(fmtInt(record.valueLength))",
            "id=\(machineEscape(record.identifier ?? "<nil>"))",
            "title=\(machineEscape(record.title ?? "<nil>"))",
            "desc=\(machineEscape(record.description ?? "<nil>"))"
        ]
        return "MACHINE|\(parts.joined(separator: "|"))"
    }

    static func scanTree(from root: AXUIElement, rootKind: RootKind, maxDepth: Int, maxNodes: Int) -> [AXNodeRecord] {
        var queue: [(AXUIElement, Int, String)] = [(root, 0, "0")]
        var out: [AXNodeRecord] = []

        while !queue.isEmpty && out.count < maxNodes {
            let (element, depth, path) = queue.removeFirst()

            let attrs = attributeNames(for: element)
            let selectedRange = cfRangeAttribute(element, kAXSelectedTextRangeAttribute as String)
            let valueString = stringAttribute(element, kAXValueAttribute as String)
            let selectedText = stringAttribute(element, kAXSelectedTextAttribute as String)
            let record = AXNodeRecord(
                element: element,
                rootKind: rootKind,
                path: path,
                depth: depth,
                role: stringAttribute(element, kAXRoleAttribute as String) ?? "<nil>",
                subrole: stringAttribute(element, kAXSubroleAttribute as String),
                title: stringAttribute(element, kAXTitleAttribute as String),
                description: stringAttribute(element, kAXDescriptionAttribute as String),
                identifier: stringAttribute(element, "AXIdentifier"),
                focused: boolAttribute(element, kAXFocusedAttribute as String),
                editable: boolAttribute(element, "AXEditable"),
                enabled: boolAttribute(element, kAXEnabledAttribute as String),
                selectedRange: selectedRange,
                selectedTextLength: selectedText?.count,
                valueLength: valueString?.count,
                hasSelectedRange: selectedRange != nil,
                hasValueString: valueString != nil,
                settableSelectedText: isAttributeSettable(element, attribute: kAXSelectedTextAttribute as String),
                settableSelectedRange: isAttributeSettable(element, attribute: kAXSelectedTextRangeAttribute as String),
                settableValue: isAttributeSettable(element, attribute: kAXValueAttribute as String),
                attrs: attrs
            )
            out.append(record)

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

    static func isStrictTextCandidate(_ r: AXNodeRecord) -> Bool {
        strictTextRoles.contains(r.role) || r.editable == true
    }

    static func isLooseWritableCandidate(_ r: AXNodeRecord) -> Bool {
        if isStrictTextCandidate(r) { return true }
        if r.hasSelectedRange { return true }
        if r.settableSelectedText == true || r.settableSelectedRange == true || r.settableValue == true {
            return true
        }
        return false
    }

    static func probeAXElementAttribute(_ element: AXUIElement, attribute: String) -> (error: AXError, element: AXUIElement?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return (result, nil)
        }
        return (result, unsafeBitCast(value, to: AXUIElement.self))
    }

    static func attributeNames(for element: AXUIElement) -> [String] {
        var namesRef: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &namesRef)
        guard result == .success, let names = namesRef as? [String] else { return [] }
        return names.sorted()
    }

    static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    static func cfRangeAttribute(_ element: AXUIElement, _ attribute: String) -> CFRange? {
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

    static func isAttributeSettable(_ element: AXUIElement, attribute: String) -> Bool? {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        guard result == .success else { return nil }
        return settable.boolValue
    }

    static func fmt(_ value: Bool?) -> String {
        guard let value else { return "<nil>" }
        return value ? "true" : "false"
    }

    static func fmtInt(_ value: Int?) -> String {
        guard let value else { return "<nil>" }
        return String(value)
    }

    static func formatRange(_ range: CFRange?) -> String {
        guard let range else { return "<nil>" }
        return "\(range.location),\(range.length)"
    }

    static func machineEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    static func axErrorString(_ error: AXError) -> String {
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

extension AXDump {
    static func pasteMenuEnabled(for pid: pid_t) -> Bool? {
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

    static func findPasteMenuItem(in menu: AXUIElement) -> AXUIElement? {
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
}

AXDump.run()
