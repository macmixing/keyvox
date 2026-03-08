import Foundation

struct iOSSessionPolicy: Equatable {
    var idleTimeout: TimeInterval?

    nonisolated static let `default` = iOSSessionPolicy(idleTimeout: 300)
}
