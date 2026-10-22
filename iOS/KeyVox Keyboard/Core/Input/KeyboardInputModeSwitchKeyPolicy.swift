/// Whether the keyboard shows its own key for switching to the next keyboard. The system asks for
/// the key through `needsInputModeSwitchKey`, except on models where it answers no while also
/// leaving out its own switch key, which leaves no way to change keyboards; those models always
/// get the key.
enum KeyboardInputModeSwitchKeyPolicy {
    private static let modelsMissingSystemSwitchKey: Set<String> = ["iPhone19,4"]

    static func showsKey(systemRequestsKey: Bool) -> Bool {
        systemRequestsKey || modelsMissingSystemSwitchKey.contains(KeyboardDeviceModel.identifier)
    }
}
