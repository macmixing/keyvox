import AppIntents
import Foundation

struct KeyVoxSpeakShortcutIntent: AppIntent {
    static let launchURL = URL(string: "keyvoxios://tts/start")!

    static var title: LocalizedStringResource { "Speak Copied Text" }
    static var description = IntentDescription("Starts the KeyVox copied-text speech route.")
    static var openAppWhenRun: Bool { true }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Speak Copied Text",
            subtitle: "Start KeyVox Speak",
            image: .init(
                named: "keyvox-circle",
                isTemplate: false,
                displayStyle: .circular
            )
        )
    }

    func perform() async throws -> some IntentResult {
        KeyVoxIPCBridge.writePendingURLRoute(Self.launchURL.absoluteString)
        return .result()
    }
}
