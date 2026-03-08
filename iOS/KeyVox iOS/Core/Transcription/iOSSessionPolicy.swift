import Foundation

struct iOSSessionPolicy: Equatable {
    var idleTimeout: TimeInterval?
    var noSpeechAbandonmentTimeout: TimeInterval?
    var postSpeechInactivityTimeout: TimeInterval?
    var emergencyUtteranceCap: TimeInterval?

    nonisolated static let `default` = iOSSessionPolicy(
        idleTimeout: 300,
        noSpeechAbandonmentTimeout: 45,
        postSpeechInactivityTimeout: 180,
        emergencyUtteranceCap: 900
    )
}
