#!/usr/bin/swift

import Cocoa
import ApplicationServices

final class ObserverState {
    let startedAt = Date()
    var records: [String] = []

    func append(_ line: String) {
        records.append(line)
        print(line)
    }
}

enum TriggerMode: String {
    case cmdv
    case menu
    case none
}

struct Config {
    var appName: String = "Slack"
    var duration: TimeInterval = 3.0
    var escapeFirst: Bool = true
    var trigger: TriggerMode = .cmdv
}

func parseConfig() -> Config {
    var config = Config()
    var i = 1
    while i < CommandLine.arguments.count {
        let arg = CommandLine.arguments[i]
        switch arg {
        case "--app":
            if i + 1 < CommandLine.arguments.count {
                config.appName = CommandLine.arguments[i + 1]
                i += 2
                continue
            }
        case "--duration":
            if i + 1 < CommandLine.arguments.count, let value = Double(CommandLine.arguments[i + 1]) {
                config.duration = max(0.1, value)
                i += 2
                continue
            }
        case "--trigger":
            if i + 1 < CommandLine.arguments.count, let mode = TriggerMode(rawValue: CommandLine.arguments[i + 1]) {
                config.trigger = mode
                i += 2
                continue
            }
        case "--no-escape-first":
            config.escapeFirst = false
            i += 1
            continue
        default:
            break
        }
        i += 1
    }
    return config
}

func boolAttr(_ element: AXUIElement, _ attr: String) -> Bool? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success else { return nil }
    return ref as? Bool
}

func stringAttr(_ element: AXUIElement, _ attr: String) -> String? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success else { return nil }
    return ref as? String
}

func cfRangeAttr(_ element: AXUIElement, _ attr: String) -> CFRange? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success,
          let value = ref,
          CFGetTypeID(value) == AXValueGetTypeID() else {
        return nil
    }
    let axValue = value as! AXValue
    var range = CFRange()
    guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
    return range
}

func formatRange(_ range: CFRange?) -> String {
    guard let range else { return "<nil>" }
    return "\(range.location),\(range.length)"
}

func elementSummary(_ element: AXUIElement) -> String {
    let role = stringAttr(element, kAXRoleAttribute as String) ?? "<nil>"
    let subrole = stringAttr(element, kAXSubroleAttribute as String) ?? "<nil>"
    let title = stringAttr(element, kAXTitleAttribute as String) ?? "<nil>"
    let desc = stringAttr(element, kAXDescriptionAttribute as String) ?? "<nil>"
    let id = stringAttr(element, "AXIdentifier") ?? "<nil>"
    let focused = boolAttr(element, kAXFocusedAttribute as String).map { $0 ? "true" : "false" } ?? "<nil>"
    let editable = boolAttr(element, "AXEditable").map { $0 ? "true" : "false" } ?? "<nil>"
    let enabled = boolAttr(element, kAXEnabledAttribute as String).map { $0 ? "true" : "false" } ?? "<nil>"
    let range = formatRange(cfRangeAttr(element, kAXSelectedTextRangeAttribute as String))
    let value = stringAttr(element, kAXValueAttribute as String)
    let valueLen = value.map { "\(($0 as NSString).length)" } ?? "<nil>"
    return "role=\(role) subrole=\(subrole) focused=\(focused) editable=\(editable) enabled=\(enabled) range=\(range) valueLen=\(valueLen) id=\(id) title=\(title) desc=\(desc)"
}

func sendEscape() {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let down = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false) else { return }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func sendCmdV() {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return }
    down.flags = .maskCommand
    up.flags = .maskCommand
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func findPasteMenuItem(in menu: AXUIElement) -> AXUIElement? {
    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
    guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }

    var subChildren: CFTypeRef?
    AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
    guard let subItems = subChildren as? [AXUIElement] else { return nil }

    for item in subItems {
        let identifier = stringAttr(item, "AXIdentifier")
        if identifier == "paste:" {
            return item
        }
        var cmdChar: CFTypeRef?
        if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar) == .success,
           let char = cmdChar as? String, char.uppercased() == "V" {
            return item
        }
        if stringAttr(item, kAXTitleAttribute as String) == "Paste" {
            return item
        }
    }
    return nil
}

func triggerMenuPaste(for pid: pid_t) {
    let app = AXUIElementCreateApplication(pid)
    var menuBar: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar) == .success,
          let menuBar,
          CFGetTypeID(menuBar) == AXUIElementGetTypeID() else {
        return
    }
    let menuBarElement = unsafeBitCast(menuBar, to: AXUIElement.self)
    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children)
    guard let topMenus = children as? [AXUIElement] else { return }

    for top in topMenus {
        if let paste = findPasteMenuItem(in: top) {
            _ = AXUIElementPerformAction(paste, kAXPressAction as CFString)
            return
        }
    }
}

func nowOffset(_ start: Date) -> String {
    String(format: "%.3f", Date().timeIntervalSince(start))
}

let config = parseConfig()
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(options)

print("AX Trusted: \(trusted ? "true" : "false")")
guard trusted else {
    fputs("Grant Accessibility access to the process running this script.\n", stderr)
    exit(2)
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == config.appName }) else {
    fputs("Could not find running app named '\(config.appName)'.\n", stderr)
    exit(3)
}

let pid = app.processIdentifier
print("Target app: \(config.appName) pid=\(pid) trigger=\(config.trigger.rawValue) duration=\(config.duration)s")

let state = ObserverState()
let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(state).toOpaque())

var observer: AXObserver?
let createError = AXObserverCreate(pid, { _, element, notification, refcon in
    guard let refcon else { return }
    let state = Unmanaged<ObserverState>.fromOpaque(refcon).takeUnretainedValue()
    let notif = notification as String
    state.append("[t+\(nowOffset(state.startedAt))] notif=\(notif) \(elementSummary(element))")
}, &observer)

guard createError == .success, let observer else {
    fputs("AXObserverCreate failed: \(createError.rawValue)\n", stderr)
    exit(4)
}

let appElement = AXUIElementCreateApplication(pid)
let notifications = [
    kAXFocusedUIElementChangedNotification as String,
    kAXFocusedWindowChangedNotification as String,
    kAXSelectedTextChangedNotification as String,
    kAXValueChangedNotification as String,
    kAXTitleChangedNotification as String
]

for name in notifications {
    let addError = AXObserverAddNotification(observer, appElement, name as CFString, refcon)
    print("Observer add \(name): \(addError.rawValue)")
}

CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

_ = app.activate(options: [])
Thread.sleep(forTimeInterval: 0.25)

if config.escapeFirst {
    sendEscape()
    Thread.sleep(forTimeInterval: 0.08)
}

switch config.trigger {
case .cmdv:
    sendCmdV()
case .menu:
    triggerMenuPaste(for: pid)
case .none:
    break
}

let until = Date().addingTimeInterval(config.duration)
while Date() < until {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}

print("Total notifications captured: \(state.records.count)")
