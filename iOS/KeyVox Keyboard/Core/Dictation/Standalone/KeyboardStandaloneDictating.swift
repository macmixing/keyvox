import Foundation

/// Dictation the keyboard runs without the containing app: it records the microphone itself
/// and has the dictation Audio Unit extension turn the recording into text.
protocol KeyboardStandaloneDictating: AnyObject {
    var onRecordingStarted: (() -> Void)? { get set }
    var onTranscriptionReady: ((String) -> Void)? { get set }
    var onNoSpeech: (() -> Void)? { get set }
    /// Called when any step fails; the dictation is over and nothing was inserted.
    var onFailure: (() -> Void)? { get set }

    var isAvailable: Bool { get }

    func start()
    func stop()
    func cancel()
    /// Cancels any dictation and lets go of the Audio Unit extension and its models.
    func deactivate()
}
