import Foundation

struct SessionPolicy: Equatable {
    var idleTimeout: TimeInterval?
    var noSpeechAbandonmentTimeout: TimeInterval?
    var postSpeechInactivityTimeout: TimeInterval?
    var emergencyUtteranceCap: TimeInterval?

    nonisolated static let `default` = SessionPolicy(
        idleTimeout: SessionDisableTiming.default.idleTimeout,
        noSpeechAbandonmentTimeout: 45,
        postSpeechInactivityTimeout: 180,
        emergencyUtteranceCap: 900
    )
}
