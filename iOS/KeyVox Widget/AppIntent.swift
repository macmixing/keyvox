import AppIntents
import CoreFoundation
import Foundation

struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("End Session", comment: "Title of the action that ends the KeyVox dictation session from the Live Activity.") }
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
