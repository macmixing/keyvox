import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Whether a swipe squiggles over a key it visits, a quick back-and-forth zigzag across the key:
/// beside a loop (`SwipeKeyLoop`), the other gesture that asks for the key's letter doubled, once a
/// repeated letter is one key of a swipe's key path.
///
/// The path near the key is walked in straight steps, each ending at the first sample `step` key
/// pitches from where it began, so a stroke straight back over the same line turns as sharply as one
/// beside it; it squiggles when its steps turn more sharply than `sharpTurn` at least `turns` times,
/// one time more where the key path itself turns more sharply than `sharpTurn` at the key (the angle
/// between the line from the previous key's center to its center and the line from its center to the
/// next key's, which a plain swipe follows; a swipe's first and last keys have none), over
/// `shortestNearTime` to `longestNearTime` seconds and `shortestNearLength` to `longestNearLength`
/// key pitches of path near the key. Both ranges' upper ends keep slow, careful swipes, which wander
/// at their keys, from reading as squiggles. Set so that none of the swipes logged on a phone beside
/// 21 deliberate squiggle swipes reads as one
/// (`~/KeyVoxLanguageData/swipe/double-letters/squiggles/README.md`).
enum SwipeKeySquiggle {
    struct Settings: Decodable, Sendable, Equatable {
        /// How near the key's center, in key pitches, the path counts as near the key.
        let nearRadius: Double
        /// The length of each straight step the path is walked in, in key pitches.
        let step: Double
        /// The least angle, in degrees, between two steps that counts as the path turning back.
        let sharpTurn: Double
        /// How many sharp turns more than the key path's own the path must make near the key.
        let turns: Int
        /// The least and most time the path spends near the key, in seconds.
        let shortestNearTime: Double
        let longestNearTime: Double
        /// The least and most length of path near the key, in key pitches.
        let shortestNearLength: Double
        let longestNearLength: Double
    }

    /// For each of the keys centered on `centers`, in a key path's order, whether `path` squiggles
    /// over it; nil when the path cannot be lined up with them.
    static func squiggledKeys(
        path: [SwipeTouchSample],
        centers: [CGPoint],
        pitch: Double,
        sampleRate: Double,
        settings: Settings
    ) -> [Bool]? {
        guard let visits = SwipeKeyVisits(path: path, centers: centers, pitch: pitch, sampleRate: sampleRate) else {
            return nil
        }
        return centers.indices.map { index in
            let pathTurns = index > 0 && index + 1 < centers.count
                && turn(from: direction(centers[index - 1], centers[index]), to: direction(centers[index], centers[index + 1])) > settings.sharpTurn
            let near = visits.visits[index].map { visits.points[$0] }.filter { distance($0, centers[index]) / pitch <= settings.nearRadius }
            return squiggles(near: near, pathTurns: pathTurns, pitch: pitch, sampleRate: sampleRate, settings: settings)
        }
    }

    /// Whether `near`, the samples of a key's visit near it, squiggle over the key; `pathTurns` is
    /// whether the key path itself turns more sharply than `sharpTurn` at the key.
    static func squiggles(near: [CGPoint], pathTurns: Bool, pitch: Double, sampleRate: Double, settings: Settings) -> Bool {
        guard near.count >= 3 else { return false }
        let time = Double(near.count) / sampleRate
        let length = zip(near, near.dropFirst()).map { distance($0, $1) }.reduce(0, +) / pitch
        return (settings.shortestNearTime...settings.longestNearTime).contains(time)
            && (settings.shortestNearLength...settings.longestNearLength).contains(length)
            && sharpTurns(near, step: settings.step * pitch, sharpTurn: settings.sharpTurn) - (pathTurns ? 1 : 0) >= settings.turns
    }

    /// How many times `points`, walked in straight steps `step` long, turn more than `sharpTurn`
    /// degrees from one step to the next.
    private static func sharpTurns(_ points: [CGPoint], step: Double, sharpTurn: Double) -> Int {
        var anchors = [points[0]]
        for point in points.dropFirst() where distance(point, anchors[anchors.count - 1]) >= step {
            anchors.append(point)
        }
        guard anchors.count >= 3 else { return 0 }
        let directions = zip(anchors, anchors.dropFirst()).map { direction($0, $1) }
        return zip(directions, directions.dropFirst()).filter { turn(from: $0, to: $1) > sharpTurn }.count
    }

    /// The direction from `a` to `b`, in radians.
    private static func direction(_ a: CGPoint, _ b: CGPoint) -> Double {
        atan2(Double(b.y - a.y), Double(b.x - a.x))
    }

    /// The angle, in degrees, between the directions `a` and `b`.
    private static func turn(from a: Double, to b: Double) -> Double {
        abs(atan2(sin(b - a), cos(b - a))) * 180 / Double.pi
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
