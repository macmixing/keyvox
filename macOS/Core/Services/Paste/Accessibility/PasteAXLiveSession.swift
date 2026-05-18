import Cocoa

protocol PasteAXLiveSessioning {
    func hasSignal() -> Bool
    func waitForSignal(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool
    func close()
}

final class PasteAXLiveSession: PasteAXLiveSessioning {
    private let processID: pid_t
    private var observer: AXObserver?
    private let runLoopSource: CFRunLoopSource
    private let runLoop: CFRunLoop
    private var isClosed = false
    private let state = State()

    private static let notifications: [String] = [
        kAXFocusedUIElementChangedNotification as String,
        kAXSelectedTextChangedNotification as String,
        kAXValueChangedNotification as String
    ]

    init?(processID: pid_t) {
        self.processID = processID
        self.runLoop = CFRunLoopGetMain()

        var createdObserver: AXObserver?
        let error = AXObserverCreate(processID, { _, element, notification, refcon in
            guard let refcon else { return }
            let session = Unmanaged<PasteAXLiveSession>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            session.handle(notification: notification as String, element: element)
        }, &createdObserver)

        guard error == .success, let createdObserver else { return nil }
        self.observer = createdObserver
        self.runLoopSource = AXObserverGetRunLoopSource(createdObserver)
        addObserverSourceToRunLoop()

        let appElement = AXUIElementCreateApplication(processID)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        for notification in Self.notifications {
            _ = AXObserverAddNotification(createdObserver, appElement, notification as CFString, refcon)
        }
    }

    deinit {
        close()
    }

    func hasSignal() -> Bool {
        state.hasSignal()
    }

    func waitForSignal(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.hasSignal() {
                return true
            }
            let until = Date().addingTimeInterval(max(0.01, pollInterval))
            RunLoop.current.run(mode: .default, before: until)
        }

        return state.hasSignal()
    }

    func close() {
        if isClosed { return }
        isClosed = true

        if let observer {
            let appElement = AXUIElementCreateApplication(processID)
            for notification in Self.notifications {
                _ = AXObserverRemoveNotification(observer, appElement, notification as CFString)
            }
            removeObserverSourceFromRunLoop()
        }

        observer = nil
    }

    private func addObserverSourceToRunLoop() {
        if Thread.isMainThread {
            CFRunLoopAddSource(runLoop, runLoopSource, .defaultMode)
            return
        }

        DispatchQueue.main.sync {
            CFRunLoopAddSource(runLoop, runLoopSource, .defaultMode)
        }
    }

    private func removeObserverSourceFromRunLoop() {
        if Thread.isMainThread {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .defaultMode)
            return
        }

        DispatchQueue.main.sync {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .defaultMode)
        }
    }

    private func handle(notification: String, element: AXUIElement) {
        guard notification == kAXValueChangedNotification as String ||
                notification == kAXSelectedTextChangedNotification as String,
              boolAttribute(element, attribute: kAXFocusedAttribute as String) == true,
              isTextTarget(element) else { return }

        state.markSignal()
    }

    private func isTextTarget(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(element, attribute: kAXRoleAttribute as String)
        if role == "AXTextField" ||
            role == "AXSearchField" ||
            role == "AXTextArea" ||
            role == "AXTextView" ||
            role == "AXComboBox" {
            return true
        }
        return boolAttribute(element, attribute: "AXEditable") == true
    }

    private func boolAttribute(_ element: AXUIElement, attribute: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? Bool
    }

    private func stringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }

    private final class State {
        private let lock = NSLock()
        private var observedSignal = false

        func markSignal() {
            lock.lock()
            observedSignal = true
            lock.unlock()
        }

        func hasSignal() -> Bool {
            lock.lock()
            let value = observedSignal
            lock.unlock()
            return value
        }
    }
}
