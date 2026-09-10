import AVFoundation
import Foundation

extension TTSPlaybackCoordinator {
    var shouldUseAsynchronousAudioSessionActivation: Bool {
        if audioSession is AVAudioSession,
           #available(iOS 27.0, *) {
            return true
        }
        return false
    }

    func activatePlaybackAudioSession() async throws {
        if let systemAudioSession = audioSession as? AVAudioSession,
           #available(iOS 27.0, *) {
            try await systemAudioSession.activateForPlayback()
            hasActivatedAudioSession = true
            return
        }

        try audioSession.setActive(true, options: [])
        hasActivatedAudioSession = true
    }

    func activatePlaybackAudioSessionSynchronously() throws {
        try audioSession.setActive(true, options: [])
        hasActivatedAudioSession = true
    }

    func deactivatePlaybackAudioSession(notifyOthers: Bool = false) async throws {
        if let systemAudioSession = audioSession as? AVAudioSession,
           #available(iOS 27.0, *) {
            try await systemAudioSession.deactivateForPlayback(notifyOthers: notifyOthers)
            hasActivatedAudioSession = false
            configuredAudioSessionMode = nil
            return
        }

        let options: AVAudioSession.SetActiveOptions = notifyOthers ? [.notifyOthersOnDeactivation] : []
        try audioSession.setActive(false, options: options)
        hasActivatedAudioSession = false
        configuredAudioSessionMode = nil
    }

    func deactivatePlaybackAudioSessionSynchronously(notifyOthers: Bool = false) throws {
        let options: AVAudioSession.SetActiveOptions = notifyOthers ? [.notifyOthersOnDeactivation] : []
        try audioSession.setActive(false, options: options)
        hasActivatedAudioSession = false
        configuredAudioSessionMode = nil
    }

    func configurePlaybackAudioSession(_ operation: @escaping (any TTSPlaybackAudioSessionControlling) throws -> Void) async throws {
        if let systemAudioSession = audioSession as? AVAudioSession,
           shouldUseAsynchronousAudioSessionActivation {
            try await systemAudioSession.performPlaybackConfiguration { audioSession in
                try operation(audioSession)
            }
            return
        }

        try operation(audioSession)
    }
}

private extension AVAudioSession {
    @available(iOS 27.0, *)
    func activateForPlayback() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            activate(options: []) { activated, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if activated {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CocoaError(.featureUnsupported))
                }
            }
        }
    }

    @available(iOS 27.0, *)
    func deactivateForPlayback(notifyOthers: Bool) async throws {
        let options: AVAudioSessionDeactivationOptions = notifyOthers ? [.notifyOthersOnDeactivation] : []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            deactivate(options: options) { deactivated, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if deactivated {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CocoaError(.featureUnsupported))
                }
            }
        }
    }

    func performPlaybackConfiguration(_ operation: @escaping (AVAudioSession) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try operation(self)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
