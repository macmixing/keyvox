import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A swipe's path lined up with the keys of a word it may have been: the path at a steady sample
/// rate, as swipe.futo.org's swipes were measured at, and for each key, the stretch of it that
/// visits that key.
///
/// Every sample goes to one of the keys, in the keys' order, each key taking at least one, so the
/// samples nearest each key in turn are that key's; a key's visit is its own samples and half of
/// each neighbor's, so a shape drawn across the boundary between two keys counts at both.
struct SwipeKeyVisits {
    /// The path at the steady rate, in points.
    let points: [CGPoint]
    /// For each key, the first and last index of its visit in `points`.
    let visits: [ClosedRange<Int>]

    /// - Parameters:
    ///   - path: The finger's samples from landing to lifting.
    ///   - centers: The keys' centers, in the path's coordinates, in the word's order.
    ///   - pitch: The key pitch, in points.
    ///   - sampleRate: Samples a second the path is read at.
    init?(path: [SwipeTouchSample], centers: [CGPoint], pitch: Double, sampleRate: Double) {
        guard centers.isEmpty == false, pitch > 0 else { return nil }
        let points = Self.resampled(path, rate: sampleRate)
        guard points.count >= max(centers.count + 1, 2) else { return nil }
        let owners = Self.owners(of: points, centers: centers, pitch: pitch)
        var firsts = [Int](repeating: points.count, count: centers.count)
        var lasts = [Int](repeating: -1, count: centers.count)
        for (index, key) in owners.enumerated() {
            firsts[key] = min(firsts[key], index)
            lasts[key] = max(lasts[key], index)
        }
        visits = centers.indices.map { key in
            let lower = key > 0 ? firsts[key] - (firsts[key] - firsts[key - 1]) / 2 : firsts[key]
            let upper = key + 1 < centers.count ? lasts[key] + (lasts[key + 1] - lasts[key]) / 2 : lasts[key]
            return max(lower, 0)...min(upper, points.count - 1)
        }
        self.points = points
    }

    /// The path at `rate` samples a second from its first sample, ending on its last; of samples
    /// sharing a time, the last counts. Times count from the first sample, so a clock's large
    /// readings cannot shift where the samples fall.
    static func resampled(_ path: [SwipeTouchSample], rate: Double) -> [CGPoint] {
        guard let start = path.map(\.timestamp).min() else { return [] }
        var samples: [(time: Double, location: CGPoint)] = []
        for sample in path.enumerated().sorted(by: {
            $0.element.timestamp != $1.element.timestamp
                ? $0.element.timestamp < $1.element.timestamp
                : $0.offset < $1.offset
        }).map(\.element) {
            let time = (sample.timestamp - start) * 1000
            if let last = samples.last, last.time == time {
                samples[samples.count - 1] = (time, sample.location)
            } else {
                samples.append((time, sample.location))
            }
        }
        guard let first = samples.first, let last = samples.last else { return [] }
        let step = 1000 / rate
        let count = Int(((last.time - first.time) / step).rounded(.up))
        var times = (0..<count).map { first.time + Double($0) * step }
        // A last sample within a nanosecond of the grid's last time is on the grid.
        if times.last.map({ $0 < last.time - 1e-6 }) ?? true {
            times.append(last.time)
        }
        var points: [CGPoint] = []
        var segment = 0
        for time in times {
            while segment + 1 < samples.count, samples[segment + 1].time <= time {
                segment += 1
            }
            guard segment + 1 < samples.count else {
                points.append(samples[segment].location)
                continue
            }
            let from = samples[segment]
            let to = samples[segment + 1]
            let share = (time - from.time) / (to.time - from.time)
            points.append(CGPoint(
                x: Double(from.location.x) + share * Double(to.location.x - from.location.x),
                y: Double(from.location.y) + share * Double(to.location.y - from.location.y)
            ))
        }
        return points
    }

    /// Which key each point goes to: the assignment in key order, every key taking at least one
    /// point, with the least total squared distance in key pitches; a tie keeps the earlier key.
    private static func owners(of points: [CGPoint], centers: [CGPoint], pitch: Double) -> [Int] {
        let keys = centers.count
        func cost(_ point: Int, _ key: Int) -> Double {
            let dx = Double(points[point].x) / pitch - Double(centers[key].x) / pitch
            let dy = Double(points[point].y) / pitch - Double(centers[key].y) / pitch
            return dx * dx + dy * dy
        }
        var total = [Double](repeating: .infinity, count: keys)
        total[0] = cost(0, 0)
        var moved = [[Bool]](repeating: [Bool](repeating: false, count: keys), count: points.count)
        for point in 1..<points.count {
            var next = [Double](repeating: .infinity, count: keys)
            for key in 0..<keys {
                let stay = total[key]
                let move = key > 0 ? total[key - 1] : .infinity
                moved[point][key] = move < stay
                next[key] = min(move, stay) + cost(point, key)
            }
            total = next
        }
        var owners = [Int](repeating: 0, count: points.count)
        var key = keys - 1
        for point in stride(from: points.count - 1, through: 0, by: -1) {
            owners[point] = key
            if point > 0, moved[point][key] {
                key -= 1
            }
        }
        return owners
    }
}
