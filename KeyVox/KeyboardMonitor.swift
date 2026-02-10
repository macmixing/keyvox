import Cocoa
import Combine
import CoreGraphics

final class KeyboardMonitor: ObservableObject {

    static let shared = KeyboardMonitor()

    // MARK: - Trigger Binding

    /// The key (or modifier) the user holds to start dictation.
    /// Stored in UserDefaults so it can be wired to a Settings UI with a simple Picker.
    enum TriggerBinding: String, CaseIterable, Identifiable {
        case leftOption
        case rightOption
        case leftCommand
        case rightCommand
        case leftControl
        case rightControl
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

        /// Returns true if this binding is currently pressed for the given flagsChanged event.
        func isPressed(for event: NSEvent) -> Bool {
            let flags = event.modifierFlags
            
            // Get the current CGEvent for precise left/right key detection
            let cgEvent = CGEvent(source: nil)
            let cgFlags = cgEvent?.flags.rawValue ?? 0

            switch self {
            case .leftOption:
                return flags.contains(.option) && (cgFlags & 0x00000020) != 0
                
            case .rightOption:
                return flags.contains(.option) && (cgFlags & 0x00000020) == 0
                
            case .leftCommand:
                return flags.contains(.command) && (cgFlags & 0x00000010) == 0
                
            case .rightCommand:
                return flags.contains(.command) && (cgFlags & 0x00000010) != 0
                
            case .leftControl:
                return flags.contains(.control) && (cgFlags & 0x00000001) != 0
                
            case .rightControl:
                return flags.contains(.control) && (cgFlags & 0x00000001) == 0
                
            case .function:
                return flags.contains(.function)
            }
        }
    }

    // MARK: - Published State

    @Published var isTriggerKeyPressed = false

    /// Expose the current binding so SwiftUI Settings can bind to it.
    @Published var triggerBinding: TriggerBinding {
        didSet {
            UserDefaults.standard.set(triggerBinding.rawValue, forKey: Self.bindingDefaultsKey)
            // Re-evaluate immediately so UI state stays correct if the user changes binding while holding keys.
            if let lastFlagsChangedEvent {
                handleModifierChange(event: lastFlagsChangedEvent)
            }
        }
    }

    // MARK: - Private

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private static let bindingDefaultsKey = "KeyVox.TriggerBinding"

    private var lastFlagsChangedEvent: NSEvent?

    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Init

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.bindingDefaultsKey),
           let saved = TriggerBinding(rawValue: raw) {
            self.triggerBinding = saved
        } else {
            // Default to left option key
            self.triggerBinding = .leftOption
        }

        startMonitoring()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard let raw = UserDefaults.standard.string(forKey: Self.bindingDefaultsKey),
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

        // Local monitor for when the app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event: event)
            return event
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
    }

    private func handleModifierChange(event: NSEvent) {
        lastFlagsChangedEvent = event

        let newState = triggerBinding.isPressed(for: event)
        if newState != isTriggerKeyPressed {
            DispatchQueue.main.async {
                self.isTriggerKeyPressed = newState
                print("Trigger key (\(self.triggerBinding.displayName)) state changed: \(newState)")
            }
        }
    }
}
