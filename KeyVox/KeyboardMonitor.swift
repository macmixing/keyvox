import Cocoa
import Combine

class KeyboardMonitor: ObservableObject {
    @Published var isTriggerKeyPressed = false
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // Using a bitmask for the Right Option key specifically
    // NX_DEVICERIGHTOPTIONKEYMASK = 0x00000040
    private let rightOptionKeyMask: UInt = 0x00000040
    
    init() {
        startMonitoring()
    }
    
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
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
    
    private func handleModifierChange(event: NSEvent) {
        // High-level mask for Option key
        let isOptionDown = event.modifierFlags.contains(.option)
        
        // Check if it's specifically the RIGHT option key
        // Note: NSEvent raw flags contain device-specific bits
        let isRightOption = (event.modifierFlags.rawValue & rightOptionKeyMask) != 0
        
        // Update state
        let newState = isOptionDown && isRightOption
        if newState != isTriggerKeyPressed {
            DispatchQueue.main.async {
                self.isTriggerKeyPressed = newState
                print("Trigger key state changed: \(newState)")
            }
        }
    }
}
