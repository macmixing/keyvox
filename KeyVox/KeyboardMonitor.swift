import Cocoa
import Combine

final class KeyboardMonitor: ObservableObject {

    static let shared = KeyboardMonitor()

    // MARK: - Trigger Binding

    /// The key (or modifier) the user holds to start dictation.
    /// Stored in UserDefaults so it can be wired to a Settings UI with a simple Picker.
    enum TriggerBinding: String, CaseIterable, Identifiable {
        case rightOption
        case anyOption
        case anyCommand
        case control
        case function

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .rightOption: return "Right Option (⌥)"
            case .anyOption: return "Option (⌥)"
            case .anyCommand: return "Command (⌘)"
            case .control: return "Control (⌃)"
            case .function: return "Fn (Function)"
            }
        }

        /// Returns true if this binding is currently pressed for the given flagsChanged event.
        func isPressed(for event: NSEvent) -> Bool {
            let flags = event.modifierFlags

            switch self {
            case .rightOption:
                // High-level mask for Option, plus a device-specific bit to distinguish RIGHT option.
                let isOptionDown = flags.contains(.option)
                let isRightOption = (flags.rawValue & KeyboardMonitor.rightOptionKeyMask) != 0
                return isOptionDown && isRightOption

            case .anyOption:
                return flags.contains(.option)

            case .anyCommand:
                return flags.contains(.command)

            case .control:
                return flags.contains(.control)

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

    // Using a bitmask for the Right Option key specifically
    // NX_DEVICERIGHTOPTIONKEYMASK = 0x00000040
    fileprivate static let rightOptionKeyMask: UInt = 0x00000040

    private var lastFlagsChangedEvent: NSEvent?

    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Init

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.bindingDefaultsKey),
           let saved = TriggerBinding(rawValue: raw) {
            self.triggerBinding = saved
        } else {
            // Keep your current default behavior.
            self.triggerBinding = .rightOption
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
