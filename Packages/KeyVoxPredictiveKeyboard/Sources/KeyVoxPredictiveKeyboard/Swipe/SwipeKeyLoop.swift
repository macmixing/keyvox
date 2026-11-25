import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Whether a swipe loops around a key it visits, the gesture that asks for the key's letter
/// doubled, once a repeated letter is one key of a swipe's key path.
///
/// On swipe.futo.org's training swipes, a loop at a key, as defined here, marks a doubled letter
/// about 40 times as often as a single one: 6.05% of key visits whose letter the word doubles, and
/// 0.139% of those it does not (`~/KeyVoxLanguageData/swipe/double-letters/README.md`).
///
/// The path near the key loops when it crosses itself, turning at least `loopTurns` between the
/// crossing's edges along the steps the finger moves at least `movingStep` (a resting finger's
/// steps have no direction), round a loop from `smallestLoopRadius` to `loopRadius` wide whose
/// middle is within `loopCenterDistance` of the key's center; smaller knots are a finger's jitter.
enum SwipeKeyLoop {
    struct Settings: Decodable, Sendable, Equatable {
        /// Samples a second the path is read at.
        let sampleRate: Double
        /// How near the key's center, in key pitches, the path counts as near the key.
        let nearRadius: Double
        /// The shortest step, in key pitches, whose direction counts toward a loop's turning.
        let movingStep: Double
        /// The least turning, in full turns, that makes a crossing a loop.
        let loopTurns: Double
        /// The narrowest a loop may be, in key pitches from its middle.
        let smallestLoopRadius: Double
        /// The widest a loop may be, in key pitches from its middle.
        let loopRadius: Double
        /// The farthest a loop's middle may be from the key's center, in key pitches.
        let loopCenterDistance: Double
    }

    /// For each of the keys centered on `centers`, in a key path's order, whether `path` loops
    /// around it; nil when the path cannot be lined up with them.
    static func loopedKeys(path: [SwipeTouchSample], centers: [CGPoint], pitch: Double, settings: Settings) -> [Bool]? {
        guard let visits = SwipeKeyVisits(path: path, centers: centers, pitch: pitch, sampleRate: settings.sampleRate) else {
            return nil
        }
        return centers.indices.map { index in
            loops(points: visits.points, range: visits.visits[index], center: centers[index], pitch: pitch, settings: settings)
        }
    }

    /// Whether the samples `range` of `points` loop around the key centered on `center`: of their
    /// crossings near the key, the first turning the most decides.
    static func loops(points: [CGPoint], range: ClosedRange<Int>, center: CGPoint, pitch: Double, settings: Settings) -> Bool {
        let near = range.map { points[$0] }.filter { distance($0, center) / pitch <= settings.nearRadius }
        guard near.count >= 3 else { return false }
        let steps = zip(near, near.dropFirst()).map { (dx: Double($1.x - $0.x), dy: Double($1.y - $0.y)) }
        let directions = steps.map { atan2($0.dy, $0.dx) }
        let moves = steps.map { ($0.dx * $0.dx + $0.dy * $0.dy).squareRoot() > settings.movingStep * pitch }
        var best: (turning: Double, radius: Double, centerDistance: Double)?
        for first in 0..<(near.count - 1) {
            for second in (first + 2)..<max(near.count - 1, first + 2) {
                guard crosses(near[first], near[first + 1], near[second], near[second + 1]) else { continue }
                let moved = (first...second).filter { moves[$0] }
                var turning = 0.0
                for (from, to) in zip(moved, moved.dropFirst()) {
                    let difference = directions[to] - directions[from]
                    turning += atan2(sin(difference), cos(difference))
                }
                turning = abs(turning)
                let loop = near[(first + 1)...second]
                let middle = CGPoint(
                    x: loop.map { Double($0.x) }.reduce(0, +) / Double(loop.count),
                    y: loop.map { Double($0.y) }.reduce(0, +) / Double(loop.count)
                )
                let radius = loop.map { distance($0, middle) }.max()! / pitch
                if best == nil || turning > best!.turning {
                    best = (turning, radius, distance(middle, center) / pitch)
                }
            }
        }
        guard let best else { return false }
        return best.turning >= settings.loopTurns * 2 * Double.pi
            && best.centerDistance <= settings.loopCenterDistance
            && best.radius >= settings.smallestLoopRadius
            && best.radius <= settings.loopRadius
    }

    private static func crosses(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func orientation(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> Double {
            Double(q.x - p.x) * Double(r.y - p.y) - Double(q.y - p.y) * Double(r.x - p.x)
        }
        return orientation(a, b, c) * orientation(a, b, d) < 0 && orientation(c, d, a) * orientation(c, d, b) < 0
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
