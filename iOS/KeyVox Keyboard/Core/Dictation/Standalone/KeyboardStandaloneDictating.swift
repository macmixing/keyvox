import Foundation

/// Dictation the keyboard runs without the containing app: it records the microphone itself
/// and has the dictation Audio Unit extension turn the recording into text.
protocol KeyboardStandaloneDictating: AnyObject {
    var onRecordingStarted: (() -> Void)? { get set }
    /// Called when recording could not start because a call holds the microphone; the
    /// dictation is over.
    var onRecordingStartFailed: (() -> Void)? { get set }
    /// Called when the recording ended without the user stopping it and is being transcribed.
    var onTranscribingStarted: (() -> Void)? { get set }
    var onTranscriptionReady: ((String) -> Void)? { get set }
    var onNoSpeech: (() -> Void)? { get set }
    /// Called when any other step fails; the dictation is over and nothing was inserted.
    var onFailure: (() -> Void)? { get set }

    var isAvailable: Bool { get }

    /// Gets everything but the microphone ready ahead of a tap; the microphone stays off.
    func prepare()
    func start()
    func stop()
    func cancel()
    /// Cancels any dictation and lets go of the Audio Unit extension and its models.
    func deactivate()
}
