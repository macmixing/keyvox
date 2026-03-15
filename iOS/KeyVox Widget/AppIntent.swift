import AppIntents
import CoreFoundation

struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "End Session" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(KeyVoxIPCBridge.Notification.disableSession as CFString),
            nil,
            nil,
            true
        )
        return .result()
    }
}
