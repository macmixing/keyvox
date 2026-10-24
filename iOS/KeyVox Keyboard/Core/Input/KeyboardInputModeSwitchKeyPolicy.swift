import UIKit

/// Whether the keyboard shows its own key for switching to the next keyboard. The system asks for
/// the key through `needsInputModeSwitchKey`, except on models where it answers no while also
/// leaving out its own switch key, which leaves no way to change keyboards; those models get the
/// key whenever another keyboard is enabled to switch to.
enum KeyboardInputModeSwitchKeyPolicy {
    // Temporary workaround for an iOS issue (FB25073949); remove once Apple fixes it.
    private static let modelsMissingSystemSwitchKey: Set<String> = ["iPhone19,4"]

    static func showsKey(systemRequestsKey: Bool) -> Bool {
        if systemRequestsKey { return true }
        return modelsMissingSystemSwitchKey.contains(KeyboardDeviceModel.identifier)
            && UITextInputMode.activeInputModes.count > 1
    }
}
