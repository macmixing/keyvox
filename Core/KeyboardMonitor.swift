import Cocoa
import Combine
import CoreGraphics

struct KeyboardModifierStateMachine {
    var leftOptionDown = false
    var rightOptionDown = false
    var leftCommandDown = false
    var rightCommandDown = false
    var leftControlDown = false
    var rightControlDown = false
    var fnDown = false

    enum KeyCode {
        static let escape: UInt16 = 53
        static let leftOption: UInt16 = 58
        static let rightOption: UInt16 = 61
        static let leftCommand: UInt16 = 55
        static let rightCommand: UInt16 = 54
        static let leftControl: UInt16 = 59
        static let rightControl: UInt16 = 62
        static let function: UInt16 = 63
    }

    mutating func update(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        // flagsChanged provides the keyCode for the modifier that changed.
        // We use it to deterministically track left/right state.
        switch keyCode {
        case KeyCode.leftOption:
            leftOptionDown = flags.contains(.option)
        case KeyCode.rightOption:
            rightOptionDown = flags.contains(.option)
        case KeyCode.leftCommand:
            leftCommandDown = flags.contains(.command)
        case KeyCode.rightCommand:
            rightCommandDown = flags.contains(.command)
        case KeyCode.leftControl:
            leftControlDown = flags.contains(.control)
        case KeyCode.rightControl:
            rightControlDown = flags.contains(.control)
        case KeyCode.function:
            fnDown = flags.contains(.function)
        default:
            break
        }

        // Safety: if the aggregate flag is not present, clear both sides.
        if !flags.contains(.option) {
            leftOptionDown = false
            rightOptionDown = false
        }
        if !flags.contains(.command) {
            leftCommandDown = false
            rightCommandDown = false
        }
        if !flags.contains(.control) {
            leftControlDown = false
            rightControlDown = false
        }

        // Fn has no left/right; keep it in sync with the aggregate flag.
        fnDown = flags.contains(.function)
    }

    func isTriggerPressed(binding: AppSettingsStore.TriggerBinding) -> Bool {
        switch binding {
        case .leftOption:
            return leftOptionDown
        case .rightOption:
            return rightOptionDown
        case .leftCommand:
            return leftCommandDown
        case .rightCommand:
            return rightCommandDown
        case .leftControl:
            return leftControlDown
        case .rightControl:
            return rightControlDown
        case .function:
            return fnDown
        }
    }
}

final class KeyboardMonitor: ObservableObject {

    static let shared = KeyboardMonitor()
    typealias TriggerBinding = AppSettingsStore.TriggerBinding

    // MARK: - Trigger Binding

    // MARK: - Published State

    @Published var isTriggerKeyPressed = false
    @Published var isShiftPressed = false
    @Published var isCapsLockOn = false

    /// Current trigger binding snapshot mirrored from `AppSettingsStore`.
    @Published private(set) var triggerBinding: TriggerBinding

    // MARK: - Private

    private let appSettings = AppSettingsStore.shared
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private var modifierState = KeyboardModifierStateMachine()
    private var lastFlagsChangedEvent: NSEvent?

    // MARK: - Init

    private init() {
        self.triggerBinding = appSettings.triggerBinding
        self.isCapsLockOn = Self.currentCapsLockState()

        startMonitoring()

        appSettings.$triggerBinding
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                guard let self else { return }
                if updated != self.triggerBinding {
                    self.triggerBinding = updated
                    // Re-evaluate immediately so UI state stays correct if the user changes
                    // binding while holding keys.
                    if let lastFlagsChangedEvent {
                        self.handleModifierChange(event: lastFlagsChangedEvent)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // Global monitor for when the app is in the background
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event: event)
        }

        // Add global keyboard monitor for Escape key
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyboardModifierStateMachine.KeyCode.escape {
                self?.handleEscapeKey()
            }
        }

        // Local monitor for when the app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event: event)
            return event
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyboardModifierStateMachine.KeyCode.escape {
                self?.handleEscapeKey()
            }
            return event
        }
    }

    @Published var escapePressedSignal = false

    private func handleEscapeKey() {
        DispatchQueue.main.async {
            self.escapePressedSignal.toggle()
        }
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalKeyDownMonitor {
            NSEvent.removeMonitor(globalKeyDownMonitor)
        }
        if let localKeyDownMonitor {
            NSEvent.removeMonitor(localKeyDownMonitor)
        }
    }

    private func handleModifierChange(event: NSEvent) {
        lastFlagsChangedEvent = event
        modifierState.update(keyCode: event.keyCode, flags: event.modifierFlags)

        let newState = modifierState.isTriggerPressed(binding: triggerBinding)
        let newShiftState = event.modifierFlags.contains(.shift)
        let newCapsLockState = event.modifierFlags.contains(.capsLock)

        if newState != isTriggerKeyPressed || newShiftState != isShiftPressed || newCapsLockState != isCapsLockOn {
            DispatchQueue.main.async {
                self.isTriggerKeyPressed = newState
                self.isShiftPressed = newShiftState
                self.isCapsLockOn = newCapsLockState
            }
        }
    }

    private static func currentCapsLockState() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
    }
}
