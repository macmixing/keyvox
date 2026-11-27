import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// One point of a swipe: where the finger was, in the keyboard's key frames' coordinates, and
/// when, in seconds on any steady clock.
public struct SwipeTouchSample: Sendable, Equatable {
    public let location: CGPoint
    public let timestamp: TimeInterval

    public init(location: CGPoint, timestamp: TimeInterval) {
        self.location = location
        self.timestamp = timestamp
    }
}
