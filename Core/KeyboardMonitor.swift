import Cocoa
import Combine
import CoreGraphics

final class KeyboardMonitor: ObservableObject {

    static let shared = KeyboardMonitor()

    // MARK: - Trigger Binding

    /// The key (or modifier) the user holds to start dictation.
    /// Stored in UserDefaults so it can be wired to a Settings UI with a simple Picker.
    enum TriggerBinding: String, CaseIterable, Identifiable {
        case rightOption
        case leftOption
        case rightCommand
        case leftCommand
        case rightControl
        case leftControl
        case function

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .leftOption: return "Left Option (⌥)"
            case .rightOption: return "Right Option (⌥)"
            case .leftCommand: return "Left Command (⌘)"
            case .rightCommand: return "Right Command (⌘)"
            case .leftControl: return "Left Control (⌃)"
            case .rightControl: return "Right Control (⌃)"
            case .function: return "Fn (Function)"
            }
        }

    }

    // MARK: - Published State

    @Published var isTriggerKeyPressed = false
    @Published var isShiftPressed = false
    @Published var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: UserDefaultsKeys.isSoundEnabled)
        }
    }

    /// Expose the current binding so SwiftUI Settings can bind to it.
    @Published var triggerBinding: TriggerBinding {
        didSet {
            UserDefaults.standard.set(triggerBinding.rawValue, forKey: UserDefaultsKeys.triggerBinding)
            // Re-evaluate immediately so UI state stays correct if the user changes binding while holding keys.
            if let lastFlagsChangedEvent {
                handleModifierChange(event: lastFlagsChangedEvent)
            }
        }
    }

    // MARK: - Private

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?

    // Track left/right modifier state deterministically from flagsChanged keyCodes
    private var leftOptionDown = false
    private var rightOptionDown = false
    private var leftCommandDown = false
    private var rightCommandDown = false
    private var leftControlDown = false
    private var rightControlDown = false
    private var fnDown = false



    private var lastFlagsChangedEvent: NSEvent?

    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Init

    private init() {
        if let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.triggerBinding),
           let saved = TriggerBinding(rawValue: raw) {
            self.triggerBinding = saved
        } else {
            // Default to right option key
            self.triggerBinding = .rightOption
        }

        self.isSoundEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.isSoundEnabled) as? Bool ?? true

        startMonitoring()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.triggerBinding),
                  let updated = TriggerBinding(rawValue: raw) else {
                return
            }

            if updated != self.triggerBinding {
                self.triggerBinding = updated
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // Global monitor for when the app is in the background
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event: event)
        }
        
        // Add global keyboard monitor for Escape key
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.handleEscapeKey()
            }
        }

        // Local monitor for when the app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event: event)
            return event
        }
        
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
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
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
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
                if newState != self.isTriggerKeyPressed {
                    #if DEBUG
                    print("Trigger key (\(self.triggerBinding.displayName)) state changed: \(newState)")
                    #endif
                }
            }
        }
    }

    private func updateModifierState(from event: NSEvent) {
        let flags = event.modifierFlags

        // flagsChanged provides the keyCode for the modifier that changed.
        // We use it to deterministically track left/right state.
        switch event.keyCode {
        case 58: // Left Option
            leftOptionDown = flags.contains(.option)
        case 61: // Right Option
            rightOptionDown = flags.contains(.option)
        case 55: // Left Command
            leftCommandDown = flags.contains(.command)
        case 54: // Right Command
            rightCommandDown = flags.contains(.command)
        case 59: // Left Control
            leftControlDown = flags.contains(.control)
        case 62: // Right Control
            rightControlDown = flags.contains(.control)
        case 63: // Fn (Function)
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
