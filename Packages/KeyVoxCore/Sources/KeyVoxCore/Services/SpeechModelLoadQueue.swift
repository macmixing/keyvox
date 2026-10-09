import Foundation

/// Runs blocking voice activity detector and Whisper model loads one at a time off the main actor.
enum SpeechModelLoadQueue {
    private static let queue = DispatchQueue(
        label: "com.cueit.keyvox.speech-model-load",
        qos: .userInitiated
    )

    static func load<Value>(_ work: @escaping () -> Value) async -> Value {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: work())
            }
        }
    }
}
