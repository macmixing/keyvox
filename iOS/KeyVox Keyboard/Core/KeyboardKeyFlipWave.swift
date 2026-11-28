import CoreGraphics
import Foundation

/// The timing of the key flip that shows a change of typing language: a wave that crosses the keys
/// in about a third of a second, each key turning over edge-on to leave and the key of the new
/// layout turning in where the wave has passed. With Reduce Motion the keys crossfade together
/// instead.
nonisolated enum KeyboardKeyFlipWave {
    /// Which way the wave crosses the keys.
    enum Direction {
        case leftToRight
        case rightToLeft
    }

    /// When one key leaves and the key in its place arrives, in seconds from the start of the wave.
    struct KeyTiming: Equatable {
        /// When the leaving key starts to turn.
        let start: TimeInterval
        /// When the leaving key is edge-on and gone, and the arriving key starts to turn in.
        let turnover: TimeInterval
        /// When the arriving key lies flat.
        let end: TimeInterval
    }

    /// How long the wave takes to reach the last key.
    static let spread: TimeInterval = 0.12
    /// How long a key takes to turn edge-on.
    static let flipOutDuration: TimeInterval = 0.1
    /// How long a key takes to turn in from edge-on.
    static let flipInDuration: TimeInterval = 0.12
    /// How long the whole wave takes.
    static let duration = spread + flipOutDuration + flipInDuration
    /// How long the keys take to crossfade with Reduce Motion.
    static let crossfadeDuration: TimeInterval = 0.2
    /// How much of the wave's delay comes from a key's row, the rest coming from how far across
    /// the keys it is, so lower rows turn a little after the rows above them.
    static let rowLag = 0.15

    /// When the key centered at `center` in keys spanning `size` turns: later the further the wave
    /// has to go to reach it.
    static func timing(forKeyAt center: CGPoint, in size: CGSize, direction: Direction) -> KeyTiming {
        let across = size.width > 0 ? min(max(center.x / size.width, 0), 1) : 0
        let down = size.height > 0 ? min(max(center.y / size.height, 0), 1) : 0
        let travelled = direction == .leftToRight ? across : 1 - across
        let start = spread * (Double(travelled) * (1 - rowLag) + Double(down) * rowLag)
        return KeyTiming(
            start: start,
            turnover: start + flipOutDuration,
            end: start + flipOutDuration + flipInDuration
        )
    }
}
