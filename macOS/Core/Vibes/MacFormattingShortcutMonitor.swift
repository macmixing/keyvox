import Cocoa
import Combine
import KeyVoxCore

final class MacFormattingShortcutMonitor {
    private let stateLock = NSLock()
    private let onShortcut: @MainActor (DictationDeterministicControlKind) -> Void
    private var shortcutState: MacFormattingShortcutStateMachine
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()

    init(
        appSettings: AppSettingsStore,
        onShortcut: @escaping @MainActor (DictationDeterministicControlKind) -> Void
    ) {
        self.shortcutState = MacFormattingShortcutStateMachine(
            triggerBinding: appSettings.triggerBinding,
            hasCompletedOnboarding: appSettings.hasCompletedOnboarding
        )
        self.onShortcut = onShortcut

        appSettings.$triggerBinding
            .sink { [weak self] binding in
                self?.updateTriggerBinding(binding)
            }
            .store(in: &cancellables)
        appSettings.$hasCompletedOnboarding
            .sink { [weak self] isComplete in
                self?.updateOnboardingState(isComplete)
            }
            .store(in: &cancellables)

        startMonitoringIfAuthorized()
    }

    func setRuntimeEnabled(_ isEnabled: Bool) {
        stateLock.withLock {
            shortcutState.setRuntimeEnabled(isEnabled)
        }
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    func startMonitoringIfAuthorized() {
        guard eventTap == nil, AXIsProcessTrusted() else {
            return
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue)
                | (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
        )
        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<MacFormattingShortcutMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            return monitor.handle(eventType: eventType, event: event)
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handle(
        eventType: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if Self.shouldRestoreEventTap(for: eventType) {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        if eventType == .flagsChanged {
            updateModifierState(keyCode: keyCode, eventFlags: event.flags)
            return Unmanaged.passUnretained(event)
        }

        if eventType == .keyUp, consumeKeyUpIfNeeded(keyCode) {
            return nil
        }

        guard eventType == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let decision = keyDownDecision(keyCode: keyCode, isRepeat: isRepeat)
        guard decision.shouldConsume else {
            return Unmanaged.passUnretained(event)
        }
        if let kind = decision.action {
            Task { @MainActor [onShortcut] in
                onShortcut(kind)
            }
        }
        return nil
    }

    private func updateModifierState(keyCode: CGKeyCode, eventFlags: CGEventFlags) {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(eventFlags.rawValue))
        stateLock.withLock {
            shortcutState.updateModifier(keyCode: keyCode, flags: flags)
        }
    }

    private func keyDownDecision(
        keyCode: CGKeyCode,
        isRepeat: Bool
    ) -> MacFormattingShortcutStateMachine.KeyDownDecision {
        stateLock.withLock {
            shortcutState.handleKeyDown(keyCode: keyCode, isRepeat: isRepeat)
        }
    }

    private func consumeKeyUpIfNeeded(_ keyCode: CGKeyCode) -> Bool {
        stateLock.withLock {
            shortcutState.handleKeyUp(keyCode: keyCode)
        }
    }

    private func updateTriggerBinding(_ binding: AppSettingsStore.TriggerBinding) {
        stateLock.withLock {
            shortcutState.updateTriggerBinding(binding)
        }
    }

    private func updateOnboardingState(_ isComplete: Bool) {
        stateLock.withLock {
            shortcutState.updateOnboardingState(isComplete)
        }
    }

    static func shouldRestoreEventTap(for eventType: CGEventType) -> Bool {
        eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput
    }
}

private extension NSLock {
    func withLock<Result>(_ operation: () -> Result) -> Result {
        lock()
        defer { unlock() }
        return operation()
    }
}
