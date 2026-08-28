import AppIntents

struct ToggleKeyVoxDictationIntent: AudioRecordingIntent, LiveActivityIntent {
    static var title: LocalizedStringResource { "Toggle KeyVox Dictation" }
    static var description = IntentDescription("Starts or stops KeyVox dictation without opening the app.")
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Toggle KeyVox Dictation",
            subtitle: "Start or stop background dictation",
            image: .init(
                named: "keyvox-circle",
                isTemplate: false,
                displayStyle: .circular
            )
        )
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        let outcome = await AppServiceRegistry.shared.shortcutDictationCoordinator.toggleRecording()

        switch outcome {
        case .recordingStarted, .noSpeech:
            return .result(value: nil as String?)
        case .transcriptionCompleted(let text):
            return .result(value: text)
        case .busy:
            throw ToggleKeyVoxDictationIntentError.busy
        case .failed(let message):
            throw ToggleKeyVoxDictationIntentError.failed(message)
        }
    }
}

private enum ToggleKeyVoxDictationIntentError: LocalizedError {
    case busy
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .busy:
            String(localized: "KeyVox is already processing dictation. Try again when it finishes.")
        case .failed(let message):
            message
        }
    }
}
