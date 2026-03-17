import Foundation

struct SessionPolicy: Equatable {
    var idleTimeout: TimeInterval?
    var noSpeechAbandonmentTimeout: TimeInterval?
    var postSpeechInactivityTimeout: TimeInterval?
    var emergencyUtteranceCap: TimeInterval?

    nonisolated static let `default` = SessionPolicy(
        idleTimeout: 300,
        noSpeechAbandonmentTimeout: 45,
        postSpeechInactivityTimeout: 180,
        emergencyUtteranceCap: 900
    )
}
