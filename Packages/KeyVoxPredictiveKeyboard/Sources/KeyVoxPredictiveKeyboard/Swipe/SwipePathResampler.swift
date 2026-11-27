import Foundation

/// Resamples a swipe to the fixed number of points the model reads: spaced evenly in time
/// from its first sample to its last and linearly interpolated, as the model's training swipes
/// were (`Tools/KeyVoxSwipeModel/prepare_swipes.py`).
enum SwipePathResampler {
    /// `points` positions as x, y pairs, from samples given as time, x, and y.
    static func resample(_ samples: [(time: Double, x: Double, y: Double)], points: Int) -> [Float] {
        guard samples.isEmpty == false, points > 0 else {
            return [Float](repeating: 0, count: points * 2)
        }
        let ordered = samples.enumerated()
            .sorted { $0.element.time != $1.element.time ? $0.element.time < $1.element.time : $0.offset < $1.offset }
            .map(\.element)
        let times = ordered.map(\.time)
        let xs = ordered.map(\.x)
        let ys = ordered.map(\.y)
        let first = times[0]
        let last = times[times.count - 1]
        guard last > first else {
            let x = Float(xs.reduce(0, +) / Double(xs.count))
            let y = Float(ys.reduce(0, +) / Double(ys.count))
            return (0..<points).flatMap { _ in [x, y] }
        }
        var output: [Float] = []
        output.reserveCapacity(points * 2)
        let step = points > 1 ? (last - first) / Double(points - 1) : 0
        var segment = 0
        for index in 0..<points {
            let target = index == points - 1 ? last : Double(index) * step + first
            while segment + 1 < times.count, times[segment + 1] <= target {
                segment += 1
            }
            output.append(Float(interpolate(target, segment, times, xs)))
            output.append(Float(interpolate(target, segment, times, ys)))
        }
        return output
    }

    /// The value at `target` between sample `segment`, the last at or before it, and the next.
    private static func interpolate(_ target: Double, _ segment: Int, _ times: [Double], _ values: [Double]) -> Double {
        guard segment + 1 < times.count else { return values[values.count - 1] }
        let slope = (values[segment + 1] - values[segment]) / (times[segment + 1] - times[segment])
        return slope * (target - times[segment]) + values[segment]
    }
}
