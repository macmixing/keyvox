import Foundation

enum TTSManagerPolicy {
    static let continuationGracePeriodNanoseconds: UInt64 = 12_000_000_000

    static func shouldPreventIdleSleep(for state: KeyVoxTTSState, isPlaybackPaused: Bool) -> Bool {
        switch state {
        case .preparing, .generating:
            return true
        case .playing:
            return isPlaybackPaused == false
        case .idle, .finished, .error:
            return false
        }
    }

    static func isActive(_ state: KeyVoxTTSState) -> Bool {
        switch state {
        case .preparing, .generating, .playing:
            return true
        case .idle, .finished, .error:
            return false
        }
    }

    static func shouldShowPreparationView(
        requested: Bool,
        fastModeEnabled: Bool,
        sourceSurface: KeyVoxTTSRequestSourceSurface
    ) -> Bool {
        requested && !(fastModeEnabled && sourceSurface == .keyboard)
    }

    static func shouldBeginBackgroundTask(
        isActive: Bool,
        fastModeEnabled: Bool,
        force: Bool
    ) -> Bool {
        guard isActive else { return false }
        return force || fastModeEnabled == false
    }
}
