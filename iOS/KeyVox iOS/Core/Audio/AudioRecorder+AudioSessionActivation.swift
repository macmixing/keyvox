import AVFoundation
import Foundation

extension AudioRecorder {
    func configureAudioSessionForRecording() async throws {
        try await performAudioSessionOperation { audioSession in
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP]
            )
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
    }

    func activateAudioSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                audioSession.activate(options: []) { activated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if activated {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: AudioRecorderError.engineStartFailed(
                                underlying: CocoaError(.featureUnsupported)
                            )
                        )
                    }
                }
            }
        } else {
            try await performAudioSessionOperation { audioSession in
                try audioSession.setActive(true)
            }
        }
    }

    func deactivateAudioSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                audioSession.deactivate(options: []) { deactivated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if deactivated {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: AudioRecorderError.engineStopFailed(
                                underlying: CocoaError(.featureUnsupported)
                            )
                        )
                    }
                }
            }
        } else {
            try await performAudioSessionOperation { audioSession in
                try audioSession.setActive(false)
            }
        }
    }

    private func performAudioSessionOperation(
        _ operation: @escaping @Sendable (AVAudioSession) throws -> Void
    ) async throws {
        let audioSession = audioSession
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try operation(audioSession)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
