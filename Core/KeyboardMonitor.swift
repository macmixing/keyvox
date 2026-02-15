import Cocoa
import Combine
import CoreGraphics

final class KeyboardMonitor: ObservableObject {

    static let shared = KeyboardMonitor()
    typealias TriggerBinding = AppSettingsStore.TriggerBinding

    // MARK: - Trigger Binding

    // MARK: - Published State

    @Published var isTriggerKeyPressed = false
    @Published var isShiftPressed = false

    /// Current trigger binding snapshot mirrored from `AppSettingsStore`.
    @Published private(set) var triggerBinding: TriggerBinding

    // MARK: - Private

    private let appSettings = AppSettingsStore.shared
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // Track left/right modifier state deterministically from flagsChanged keyCodes
    private var leftOptionDown = false
    private var rightOptionDown = false
    private var leftCommandDown = false
    private var rightCommandDown = false
    private var leftControlDown = false
    private var rightControlDown = false
    private var fnDown = false
    private var lastFlagsChangedEvent: NSEvent?
    
    private enum KeyCode {
        static let escape: UInt16 = 53
        static let leftOption: UInt16 = 58
        static let rightOption: UInt16 = 61
        static let leftCommand: UInt16 = 55
        static let rightCommand: UInt16 = 54
        static let leftControl: UInt16 = 59
        static let rightControl: UInt16 = 62
        static let function: UInt16 = 63
    }

    // MARK: - Init

    private init() {
        self.triggerBinding = appSettings.triggerBinding

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
            if event.keyCode == KeyCode.escape { // Escape
                self?.handleEscapeKey()
            }
        }

        // Local monitor for when the app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event: event)
            return event
        }
        
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyCode.escape { // Escape
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
        updateModifierState(from: event)

        let newState = isTriggerPressed()
        let newShiftState = event.modifierFlags.contains(.shift)
        
        if newState != isTriggerKeyPressed || newShiftState != isShiftPressed {
            DispatchQueue.main.async {
                self.isTriggerKeyPressed = newState
                self.isShiftPressed = newShiftState
            }
        }
    }

    private func updateModifierState(from event: NSEvent) {
        let flags = event.modifierFlags

        // flagsChanged provides the keyCode for the modifier that changed.
        // We use it to deterministically track left/right state.
        switch event.keyCode {
        case KeyCode.leftOption: // Left Option
            leftOptionDown = flags.contains(.option)
        case KeyCode.rightOption: // Right Option
            rightOptionDown = flags.contains(.option)
        case KeyCode.leftCommand: // Left Command
            leftCommandDown = flags.contains(.command)
        case KeyCode.rightCommand: // Right Command
            rightCommandDown = flags.contains(.command)
        case KeyCode.leftControl: // Left Control
            leftControlDown = flags.contains(.control)
        case KeyCode.rightControl: // Right Control
            rightControlDown = flags.contains(.control)
        case KeyCode.function: // Fn (Function)
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

    private func isTriggerPressed() -> Bool {
        switch triggerBinding {
        case .leftOption: return leftOptionDown
        case .rightOption: return rightOptionDown
        case .leftCommand: return leftCommandDown
        case .rightCommand: return rightCommandDown
        case .leftControl: return leftControlDown
        case .rightControl: return rightControlDown
        case .function: return fnDown
        }
    }
}
